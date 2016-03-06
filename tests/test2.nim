import ../jsmn

type
  Student = object
    name: string
    age: int
    points: seq[int]
    friends: seq[Student]
let js = """{"name": "John", "age": 30, "points": [], "friends": [{"name": "Bob"}, {"name": "Peter", "age": 8}]}"""

var j = Jsmn(js)
let n = j["friends"][1]
echo n.hasKey("age")
echo n["age"].toInt

var f: Student
f.name = "Smith"
f.age = 40
f.points = @[]
var s: Student
s.name = "John Doe"
s.age = 20
s.points = @[1,2,3,4,5]
s.friends = @[f]

var json = newStringOfCap(sizeof(s))
stringify(s, json)
echo json

echo getTotalMem(), ", ", getOccupiedMem(), ", ", getFreeMem()
