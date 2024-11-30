* Set activitywatch settings:
  * ```aw-manager settings -s config.json```

* Get activitywatch settings:
  * ```aw-manager settings -g output.json```

* Get activitywatch buckets:
  * ```aw-manager buckets -g buckets_backup.json```

* Set activitywatch buckets:
  * ```aw-manager buckets -s buckets.json```

* Add custom visualizer:
  * Pass it as an argument to `aw-server`
    * ```aw-server --custom-static aw-watcher-system=/home/emre/Desktop/dotfiles/.config/activitywatch/aw-watcher-system/visualization```

* Use local libs in custom visualizations:
  * Download the js and give its path in index.html
    * <script src="libs/chart.min.js"></script>
