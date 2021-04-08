# jsmn.nim
Jsmn - a world fastest JSON parser - in pure Nim

According to this [benchmark script](https://github.com/rgv151/benchmarking/blob/master/marshal_vs_manual.nim) with about 3MB JSON of World Bank dataset, JSMN is 2-2.5 times faster than marshal
![Benchmark result](https://downloader.disk.yandex.ru/preview/cf0d5b53d98f7cda33484e56c649191039f82b86881b3503036519749dc024c4/5cd67ba6/VfrKkos1WSzVs-j90gCy1dLWs5PgJjdR9UWqcKxrIQanHRc9n9sSz-cpXvhmPbYDjgRKWmvIzouyDrKjw7WpMg%3D%3D?uid=0&filename=2019-05-11_10-36-59.png&disposition=inline&hash=&limit=0&content_type=image%2Fpng&tknv=v2&size=2048x2048)

![Benchmark result](https://downloader.disk.yandex.ru/preview/5e9d24e4155569765445535b978ebe667be82f3e59e043d5660206bbc1962f35/5cd67bc1/oYyULY8MIiYSd38io7nHmFGwy328Wd2tvLWnCBwe_lAytqCmtXVpzWSqRPygSkuBLfNI-SJxBOCzJ4bsXajIcA%3D%3D?uid=0&filename=2019-05-11_10-37-29.png&disposition=inline&hash=&limit=0&content_type=image%2Fpng&tknv=v2&size=2048x2048)

## Usage

```nim
import jsmn
const
  json = """{
    "user": "johndoe",
    "admin": false,
    "uid": 1000,
    "groups": ["users", "wheel", "audio", "video"]}"""

var tokens = newSeq[JsmnToken](32) # expect not more than 32 tokens
let r = parseJson(json, tokens)

for i in 1..r:
  var token = addr tokens[i]
  echo "Kind: ", token.kind
  echo "Value: ", json[token.start..<token.stop]

```
