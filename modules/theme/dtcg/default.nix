let
  inherit (builtins)
    attrNames
    bitAnd
    concatStringsSep
    elem
    filter
    floor
    foldl'
    fromJSON
    hasAttr
    head
    isAttrs
    isBool
    isFloat
    isInt
    isList
    isString
    length
    listToAttrs
    mapAttrs
    match
    readFile
    replaceStrings
    split
    substring
    tail
    toJSON
    ;

  knownKeys = [
    "$deprecated"
    "$description"
    "$extensions"
    "$type"
    "$value"
  ];

  tokenTypes = [
    "border"
    "color"
    "cubicBezier"
    "dimension"
    "duration"
    "fontFamily"
    "fontWeight"
    "gradient"
    "number"
    "shadow"
    "strokeStyle"
    "transition"
    "typography"
  ];

  fontWeights = {
    thin = 100;
    hairline = 100;
    "extra-light" = 200;
    "ultra-light" = 200;
    light = 300;
    normal = 400;
    regular = 400;
    book = 400;
    medium = 500;
    "semi-bold" = 600;
    "demi-bold" = 600;
    bold = 700;
    "extra-bold" = 800;
    "ultra-bold" = 800;
    black = 900;
    heavy = 900;
    "extra-black" = 950;
    "ultra-black" = 950;
  };

  namePattern = "[^\${}.][^{}.]*";
  aliasPattern = "[{](${namePattern}([.]${namePattern})*)[}]";

  isReserved = name: substring 0 1 name == "$";
  isToken = node: isAttrs node && hasAttr "$value" node;

  show = path: concatStringsSep "." path;
  childNames = node: filter (name: !isReserved name) (attrNames node);

  aliasPath =
    value:
    if !(isString value) then
      null
    else
      let
        captures = match aliasPattern value;
      in
      if captures == null then null else filter isString (split "\\." (head captures));

  digits = "0123456789abcdef";

  componentByte =
    path: component:
    if !(isFloat component || isInt component) then
      throw "dtcg: ${show path} has a colour component that is not a number"
    else if component < 0.0 || component > 1.0 then
      throw "dtcg: ${show path} has colour component ${toString component} outside 0 to 1"
    else
      floor (component * 255.0 + 0.5);

  hexPair = byte: "${substring (byte / 16) 1 digits}${substring (bitAnd byte 15) 1 digits}";

  colorHex =
    path: value:
    let
      alpha = value.alpha or 1;
      derived = "#" + concatStringsSep "" (map (c: hexPair (componentByte path c)) value.components);
    in
    if value.colorSpace != "srgb" then
      throw "dtcg: ${show path} is a ${value.colorSpace} colour and this reader only projects srgb"
    else if !(isList value.components) || length value.components != 3 then
      throw "dtcg: ${show path} does not carry three srgb components"
    else if alpha != 1 then
      throw "dtcg: ${show path} is translucent and no consumer of this reader accepts an alpha"
    else if value ? hex && value.hex != derived then
      throw "dtcg: ${show path} has components worth ${derived} but a hex fallback of ${value.hex}"
    else
      derived;

  scalar =
    path: type: value:
    {
      color = colorHex path value;

      dimension =
        if value.unit != "px" then
          throw "dtcg: ${show path} is measured in ${value.unit} and this reader only projects px"
        else
          value.value;

      duration =
        if value.unit != "ms" then
          throw "dtcg: ${show path} is measured in ${value.unit} and this reader only projects ms"
        else
          value.value;

      fontFamily = value;
      fontWeight =
        if isString value then
          fontWeights.${value} or (throw "dtcg: ${show path} has an unknown font weight ${value}")
        else
          value;
      cubicBezier = value;
      number = value;
    }
    .${type}
      or (throw "dtcg: ${show path} is a ${type} token and this reader does not project that type");

  document =
    path:
    let
      raw = fromJSON (readFile path);
      keys = filter (name: name != "$schema") (attrNames raw);
      reserved = filter isReserved keys;
    in
    if !(isAttrs raw) then
      throw "dtcg: ${toString path} is not a token document"
    else if reserved != [ ] then
      throw "dtcg: ${toString path} carries ${head reserved} at its root, which the merged document cannot own"
    else
      listToAttrs (
        map (name: {
          inherit name;
          value = raw.${name};
        }) keys
      );

  merge =
    path: left: right:
    foldl' (
      acc: name:
      let
        here = path ++ [ name ];
      in
      if !(hasAttr name acc) then
        acc // { ${name} = right.${name}; }
      else if isToken acc.${name} || isToken right.${name} then
        throw "dtcg: ${show here} is defined more than once"
      else if !(isAttrs acc.${name}) || !(isAttrs right.${name}) then
        throw "dtcg: ${show here} is defined more than once"
      else
        acc // { ${name} = merge here acc.${name} right.${name}; }
    ) left (attrNames right);

  load =
    paths:
    let
      root = foldl' (merge [ ]) { } (map document paths);

      locate =
        wanted:
        foldl' (
          node: name:
          if isAttrs node && !(isReserved name) && hasAttr name node then
            node.${name}
          else
            throw "dtcg: {${show wanted}} does not name anything"
        ) root wanted;

      declaredType =
        wanted:
        foldl' (
          carried: node: if isAttrs node && hasAttr "$type" node then node."$type" else carried
        ) null (scanl wanted);

      scanl =
        wanted:
        let
          step = node: rest: [ node ] ++ (if rest == [ ] then [ ] else step node.${head rest} (tail rest));
        in
        step root wanted;

      token =
        trail: wanted:
        let
          key = show wanted;
          node = locate wanted;
          walked = trail ++ [ key ];
          target = aliasPath node."$value";
          declared = declaredType wanted;
          referenced = if target == null then null else token walked target;
          type =
            if declared == null then
              (
                if referenced == null then
                  throw "dtcg: ${key} has no $type and no group above it declares one"
                else
                  referenced.type
              )
            else if !(elem declared tokenTypes) then
              throw "dtcg: ${key} has an unknown $type of ${declared}"
            else if referenced != null && referenced.type != declared then
              throw "dtcg: ${key} is a ${declared} token but {${show target}} is a ${referenced.type} token"
            else
              declared;
        in
        if elem key trail then
          throw "dtcg: reference cycle ${concatStringsSep " -> " walked}"
        else if !(isToken node) then
          throw "dtcg: {${key}} names a group, not a token"
        else
          {
            inherit type;
            value = if target == null then inner walked node."$value" else referenced.value;
          };

      inner =
        trail: value:
        if isList value then
          map (inner trail) value
        else if isAttrs value then
          if hasAttr "$ref" value then
            throw "dtcg: a JSON Pointer reference appears in ${head trail}, which this reader does not implement"
          else
            mapAttrs (_: inner trail) value
        else
          let
            target = aliasPath value;
          in
          if target == null then value else (token trail target).value;

      visit =
        path: node:
        let
          keys = attrNames node;
          unsupported = filter (name: isReserved name && !(elem name knownKeys)) keys;
          children = childNames node;
          named = filter (name: match namePattern name == null) children;
          carried = if node ? "$extensions" then { "$extensions" = node."$extensions"; } else { };
        in
        if !(isAttrs node) then
          throw "dtcg: ${show path} is neither a token nor a group"
        else if unsupported != [ ] then
          throw "dtcg: ${show path} carries ${head unsupported}, which this reader does not implement"
        else if named != [ ] then
          throw "dtcg: ${show (path ++ [ (head named) ])} is not a usable token or group name"
        else if isToken node then
          if children != [ ] then
            throw "dtcg: ${show path} holds both a $value and the name ${head children}"
          else
            let
              resolved = token [ ] path;
            in
            carried
            // {
              "$type" = resolved.type;
              "$value" = resolved.value;
            }
        else
          carried
          // listToAttrs (
            map (name: {
              inherit name;
              value = visit (path ++ [ name ]) node.${name};
            }) children
          );

      tree = visit [ ] root;
    in
    builtins.deepSeq tree tree;

  project =
    path: node:
    if !(isAttrs node) then
      throw "dtcg: ${show path} is neither a resolved token nor a resolved group"
    else if isToken node then
      scalar path node."$type" node."$value"
    else
      listToAttrs (
        map (name: {
          inherit name;
          value = project (path ++ [ name ]) node.${name};
        }) (childNames node)
      );

  read =
    node:
    let
      projected = project [ ] node;
    in
    builtins.deepSeq projected projected;

  extensions = node: node."$extensions" or { };

  members =
    node:
    listToAttrs (
      map (name: {
        inherit name;
        value = node.${name};
      }) (childNames node)
    );
  literalFloat =
    number:
    let
      printed = toString number;
      whole = match "(-?[0-9]+)\\.?0*" printed;
      fraction = match "(-?[0-9]+\\.[0-9]*[1-9])0*" printed;
    in
    if fraction != null then
      head fraction
    else if whole != null then
      "${head whole}.0"
    else
      printed;

  literalString = text: replaceStrings [ "\${" ] [ "\\\${" ] (toJSON text);

  literalName =
    name: if match "[a-zA-Z_][a-zA-Z0-9_'-]*" name != null then name else literalString name;

  render =
    atomic: value:
    let
      parenthesise = printed: if atomic && substring 0 1 printed == "-" then "(${printed})" else printed;
    in
    if value == null then
      "null"
    else if isBool value then
      (if value then "true" else "false")
    else if isString value then
      literalString value
    else if isInt value then
      parenthesise (toString value)
    else if isFloat value then
      parenthesise (literalFloat value)
    else if isList value then
      "[ ${concatStringsSep " " (map (render true) value)} ]"
    else if isAttrs value then
      "{ ${
        concatStringsSep " " (
          map (name: "${literalName name} = ${render false value.${name}};") (attrNames value)
        )
      } }"
    else
      throw "dtcg: emit cannot render this value as Nix source";

  emit = render false;
in
{
  inherit
    load
    read
    extensions
    members
    emit
    ;
}
