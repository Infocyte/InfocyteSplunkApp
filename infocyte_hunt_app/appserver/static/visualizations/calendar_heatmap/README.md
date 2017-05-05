# Calendar Heat Map

Documentation:
http://docs.splunk.com/Documentation/CustomViz/1.0.0/CalendarHeatMap/CalendarHeatMapIntro

## Sample Queries

```
index=_internal | timechart span=1d count by sourcetype
```