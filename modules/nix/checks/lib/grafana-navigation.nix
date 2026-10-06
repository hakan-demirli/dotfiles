{ pkgs, self, ... }:
let
  observability = self.nixosConfigurations.vps-oracle-0;
  module = import ../../../services/grafana-fleet.nix {
    inherit pkgs;
    inherit (observability) config;
    inputs = self.inputs // {
      inherit self;
    };
    cluster = self.lib.inventory;
    inherit (pkgs) lib;
  };
  dashboards =
    (builtins.head module.services.grafana.provision.dashboards.settings.providers).options.path;
  journalProgram = pkgs.writeText "journal-context.vrl" self.nixosConfigurations.laptop-1.config.services.vector.settings.transforms.journal-context.source;
  journalEvents = pkgs.writeText "journal-events.jsonl" ''
    {"unit":"user@1000.service","_SYSTEMD_USER_UNIT":"notes-backup.service","_UID":"1000","message":"fatal: Could not resolve host: github.com"}
    {"unit":"user@1000.service","USER_UNIT":"state-backup.service","_UID":"1000","message":"Failed with result 'exit-code'."}
    {"unit":"init.scope","UNIT":"btrfs-scrub@-.service","message":"Failed with result 'exit-code'."}
    {"unit":"sshd.service","message":"Accepted publickey"}
  '';
in
assert
  observability.config.services.vector.settings.sinks.victorialogs.inputs == [
    "journal-context"
    "router-label"
  ];
assert
  self.nixosConfigurations.server-dev-1.config.services.vector.settings.sinks.victorialogs.inputs
  == [ "journal-context" ];
pkgs.runCommand "grafana-navigation"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.vector
    ];
    inherit dashboards journalProgram journalEvents;
  }
  ''
    vector vrl --program "$journalProgram" --input "$journalEvents" --print-object > journal-results.jsonl
    python3 - "$dashboards" journal-results.jsonl <<'PY'
    import json
    import pathlib
    import re
    import sys
    import urllib.parse

    dashboards = {
        document["uid"]: document
        for path in pathlib.Path(sys.argv[1]).glob("*.json")
        for document in [json.loads(path.read_text())]
    }

    def links(panel):
        yield from panel.get("links", [])
        fields = panel.get("fieldConfig", {})
        yield from fields.get("defaults", {}).get("links", [])
        for override in fields.get("overrides", []):
            for prop in override["properties"]:
                if prop["id"] == "links":
                    yield from prop["value"]

    substitutions = {
        "datasource:percentencode": "metrics-test",
        "__from": "1791180000000",
        "__to": "1791200000000",
        "__url_time_range": "from=1791180000000&to=1791200000000",
        "__field.labels.host:percentencode": "server-dev-1",
        '__data.fields["Host"]:percentencode': "server-dev-1",
        '__data.fields["Manager"]:percentencode': "system",
        '__data.fields["Unit"]:percentencode': urllib.parse.quote("btrfs-scrub@-.service", safe=""),
    }

    for dashboard in dashboards.values():
        panels = dashboard["panels"]
        ids = [panel["id"] for panel in panels]
        assert len(ids) == len(set(ids)), dashboard["title"]
        for panel in panels:
            panel_links = list(links(panel))
            if dashboard["uid"] == "fleet-revisions" and panel["type"] != "row":
                assert panel_links, f"Dead-end panel: {panel['title']}"
            for link in panel_links:
                url = re.sub(r"\$\{([^}]+)\}", lambda m: substitutions.get(m[1], m[0]), link["url"])
                parsed = urllib.parse.urlsplit(url)
                query = urllib.parse.parse_qs(parsed.query)
                if parsed.path.startswith("/d/"):
                    uid = parsed.path.split("/")[2]
                    assert uid in dashboards, link
                    if "viewPanel" in query:
                        assert int(query["viewPanel"][0]) in {p["id"] for p in dashboards[uid]["panels"]}, link
                    else:
                        names = {v["name"] for v in dashboards[uid]["templating"]["list"]}
                        assert all(key[4:] in names for key in query if key.startswith("var-")), link
                if parsed.path == "/explore":
                    panes = json.loads(query["panes"][0])
                    assert panes["A"]["range"] == {"from": substitutions["__from"], "to": substitutions["__to"]}
                    assert panes["A"]["queries"], link

    overview = {p["id"]: p for p in dashboards["fleet-revisions"]["panels"]}
    for id in (7, 24):
        assert any("/d/service-failures?" in link["url"] for link in links(overview[id])), id
    assert any('var-unit=''${__data.fields["Unit"]:percentencode}' in link["url"] for link in links(overview[33]))
    failures = dashboards["service-failures"]
    assert failures["time"]["from"] == "now-30d"
    assert {"host", "manager", "unit"}.issubset({v["name"] for v in failures["templating"]["list"]})
    log_panels = [p for p in failures["panels"] if p["type"] == "logs"]
    assert len(log_panels) == 2
    for panel in log_panels:
        query = panel["targets"][0]["expr"]
        assert "''${host:json}" in query and "''${unit:json}" in query
        assert "_SYSTEMD_USER_UNIT" in query and "USER_UNIT" in query and "UNIT:" in query
    assert "could not" in log_panels[0]["targets"][0]["expr"]

    events = [json.loads(line) for line in pathlib.Path(sys.argv[2]).read_text().splitlines()]
    assert [(e["unit"], e["manager"]) for e in events] == [
        ("notes-backup.service", "emre"),
        ("state-backup.service", "emre"),
        ("btrfs-scrub@-.service", "system"),
        ("sshd.service", "system"),
    ]
    assert events[0]["journal_unit"] == "user@1000.service"
    assert events[0]["message"] == "fatal: Could not resolve host: github.com"
    print("Dashboard links, failure drill-downs, and journal correlation passed")
    PY
    touch "$out"
  ''
