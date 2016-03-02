import ../jsmn

type
  Student = object
    name: string
    age: int
    points: seq[int]
    friends: seq[Student]
let js = """{"name": "John", "age": 30, "points": [], "friends": [{"name": "Bob"}]}"""

var j = Jsmn(js)
let n = j["friends"][0]
echo n.hasKey("name")
echo j["age"].getInt()

echo getTotalMem(), ", ", getOccupiedMem(), ", ", getFreeMem()
