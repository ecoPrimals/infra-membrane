#!/bin/bash
# compact-feeds.sh — regenerate π-compressed data feeds
# Merges individual feeds into compact combined files
# Run after any feed writer updates its output

cd /opt/membrane/live-terminal

# stories.json = billboard-mix + page-stories + visitor-stories
python3 -c "
import json, sys
stories = {}
for name in [billboard-mix, page-stories, visitor-stories]:
    try: stories[name.replace(-,_)] = json.load(open(f{name}.json))
    except: pass
json.dump(stories, open(stories.json, w))
" 2>/dev/null

# membrane-deep.json = membrane + membrane-stack + falsification
python3 -c "
import json
deep = {}
for name in [membrane, membrane-stack, falsification]:
    try: deep[name.replace(-,_)] = json.load(open(f{name}.json))
    except: pass
json.dump(deep, open(membrane-deep.json, w))
" 2>/dev/null

# signals.json = campfire + scatter-observatory
python3 -c "
import json
signals = {}
for name in [campfire, scatter-observatory]:
    try: signals[name.replace(-,_)] = json.load(open(f{name}.json))
    except: pass
json.dump(signals, open(signals.json, w))
" 2>/dev/null

# topology-compact.json = slim topology
python3 -c "
import json
try:
    t = json.load(open(topology.json))
    compact = {ts: t.get(generated_iso,), analyzed: t.get(log_entries_analyzed,0), entities: []}
    for e in t.get(entities, []):
        compact[entities].append({
            name: e.get(entity,), label: e.get(label,),
            fleet: e.get(is_fleet,False), honest: e.get(is_honest,False),
            reqs: e.get(total_requests,0), ips: e.get(unique_ips,0)
        })
    json.dump(compact, open(topology-compact.json, w), indent=2)
except: pass
" 2>/dev/null
