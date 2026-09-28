{
  host = ''{{ reReplaceAll "^([^.:]+).*$" "$1" $labels.instance }}'';
}
