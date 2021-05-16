
```
cat contracts/**/*.json | jq '.abi[] | select(.type == "event") | { name: .name, types: [.inputs[].type] }'
```
