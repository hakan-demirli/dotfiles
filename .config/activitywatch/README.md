* Set activitywatch settings:
  * ```aw-settings -s ./config.json```

* Get activitywatch settings:
  * ```aw-settings -g ./output.json```

* Add custom visualizer:
  * Pass it as an argument to `aw-server`
    * ```aw-server --custom-static aw-watcher-system=/home/emre/Desktop/dotfiles/.config/activitywatch/aw-watcher-system/visualization```

* Use local libs in custom visualizations:
  * Download the js and give its path in index.html
    * <script src="libs/chart.min.js"></script>
