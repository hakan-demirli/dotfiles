{
  model = "GWN7721";

  ports = [
    "2.5GE1"
    "2.5GE2"
    "2.5GE3"
    "2.5GE4"
    "2.5GE5"
    "2.5GE6"
    "2.5GE7"
    "2.5GE8"
    "SFP+9"
    "SFP+10"
  ];

  api = {
    scheme = "http";
    port = 80;
    readPath = "/get.cgi";
    writePath = "/set.cgi";
  };
}
