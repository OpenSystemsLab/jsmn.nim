# jsmn.nim
Jsmn - a world fastest JSON parser - in pure Nim

According to this [benchmark script](https://github.com/rgv151/benchmarking/blob/master/marshal_vs_manual.nim) with about 3MB JSON of World Bank dataset, JSMN is 1.5 - 2 times faster than marshal
![Benchmark result](http://pix.toile-libre.org/upload/original/1456796039.png)


## Usage

```nim

const
  json = """{
    "user": "johndoe",
    "admin": false,
    "uid": 1000,
    "groups": ["users", "wheel", "audio", "video"]}"""
    
var tokens: array[32, JsmnToken] # expect not more than 32 tokens
let r = parseJson(json, tokens)

for i in 1..r:
  var token = addr tokens[i]
  echo "Kind: ", token.kind
  echo "Value: ", json[token.start..<token.stop]

```