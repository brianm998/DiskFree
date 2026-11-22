# 0837 Store hidden volumes, not shown ones

Selection is kept as hidden sets (local by name, network by localMount) so new volumes show by default and "Clear All" persists. An old `localVolumesToShow` is used once, at the first discovery, to derive the hidden set. Discovery and the first network reconcile await the preference-load task.
