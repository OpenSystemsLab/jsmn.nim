# Copyright 2016 Huy Doan
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# This file is a Nim fork of Jsmn: https://github.com/zserge/jsmn
# Copyright (c) 2010 Serge A. Zaitsev
#

## This module is a fork of `Jsmn <http://zserge.com/jsmn.html>`_ - a world fastest JSON parser/tokenizer - in pure Nim
##
## It also supports ``PARENT LINKS`` and ``STRICT MODE``, you can enable them via command line switch
##
## Installation
## ============
##.. code-block::
##  nimble install jsmn
##
## Usage
## =====
##.. code-block:: nim
##  import jsmn
##
##  const
##    json = """{
##      "user": "johndoe",
##      "admin": false,
##      "uid": 1000,
##      "groups": ["users", "wheel", "audio", "video"]}"""
##
##  var
##    tokens: array[32, JsmnToken] # expect not more than 32 tokens
##
##  let r = parseJson(json, tokens)
##
##  for i in 1..r:
##    var token = addr tokens[i]
##    echo "Kind: ", token.kind
##    echo "Value: ", json[token.start..<token.stop]

type
  JsmnKind* = enum ## JSON type identifier
    JSMN_UNDEFINED, ## Undefined
    JSMN_OBJECT, ## Object, tuple
    JSMN_ARRAY, ## Array, seq
    JSMN_STRING, ## String
    JSMN_PRIMITIVE ## Other primitive: number, boolean (true/false) or null

  JsmnToken* = object
    ## JSON token description.
    kind*: JsmnKind
    start*: int ## start position in JSON data string
    stop*: int ## end position in JSON data string
    size*: int
    when not defined(JSMN_NO_PARENT_LINKS):
      parent*: int

  JsmnParser = object
    pos: int
    toknext: int
    toksuper: int

  JsmnException* = object of ValueError

  JsmnNotEnoughTokensException* = object of JsmnException
    ## not enough tokens, JSON string is too large
  JsmnBadTokenException = object of JsmnException
    ## bad token, JSON string is corrupted
  JsmnNotEnoughJsonDataException* = object of JsmnException
    ## JSON string is too short, expecting more JSON data
const
  JSMN_TOKENS = 256

when defined(JSMN_STRICT):
  # In strict mode primitive must be followed by "," or "}" or "]"
  const PRIMITIVE_DELIMITERS = ['\x09', '\x0D', '\x0A', ' ', ',', ']', '}']
else:
  const PRIMITIVE_DELIMITERS = [':', '\x09', '\x0D', '\x0A', ' ', ',', ']', '}']

proc `$`(p: JsmnParser): string =
  "JsmnParser[Position: " & $p.pos  & ", NextTokenIndex: " & $p.toknext & ", SuperTokenIndex: " & $p.toksuper & "]"

{.push boundChecks: off, overflowChecks: off.}

proc initToken(parser: var JsmnParser, tokens: var openarray[JsmnToken], kind = JSMN_UNDEFINED, start, stop = -1): ptr JsmnToken =
  ## Allocates a token and fills type and boundaries.
  if parser.toknext >= tokens.len:
    raise newException(JsmnNotEnoughTokensException, $parser)

  result = addr tokens[parser.toknext]
  result.kind = kind
  result.start = start
  result.stop = stop
  when not defined(JSMN_NO_PARENT_LINKS):
    result.parent = -1

  inc(parser.toknext)


template found(): untyped =
  if tokens.len <= 0:
    dec(parser.pos)
    return
  var token = initToken(parser, tokens, JSMN_PRIMITIVE, start, parser.pos)
  when not defined(JSMN_NO_PARENT_LINKS):
    token.parent = parser.toksuper
    assert tokens[token.parent].kind != JSMN_STRING and tokens[token.parent].kind != JSMN_PRIMITIVE
  dec(parser.pos)
  return

proc parsePrimitive(parser: var JsmnParser, tokens: var openarray[JsmnToken], json: string, length: int) =
  ## Fills next available token with JSON primitive.
  var start = parser.pos
  while parser.pos < length and json[parser.pos] != '\0':
    let c = json[parser.pos]
    when defined(JSMN_STRICT):
      if c == ':':
        found()
    else:
      if c in ['\x09', '\x0D', '\x0A', ' ', ',', ']', '}']:
        found()

    if json[parser.pos].ord < 32 or json[parser.pos].ord >= 127:
      raise newException(JsmnBadTokenException, $parser)
    inc(parser.pos)
  when defined(JSMN_STRICT):
    # In strict mode primitive must be followed by a comma/object/array
    raise newException(JsmnBadTokenException, $parser)

proc parseString(parser: var JsmnParser, tokens: var openarray[JsmnToken], json: string, length: int) =
  ## Fills next token with JSON string.
  let start = parser.pos
  inc(parser.pos)
  # Skip starting quote
  while parser.pos < length and json[parser.pos] != '\0':
    let c = json[parser.pos]
    # Quote: end of string
    if c == '"':
      var token = initToken(parser, tokens, JSMN_STRING, start + 1, parser.pos)
      when not defined(JSMN_NO_PARENT_LINKS):
        token.parent = parser.toksuper
        assert tokens[token.parent].kind != JSMN_STRING and tokens[token.parent].kind != JSMN_PRIMITIVE
      return
    if c == '\x08' and parser.pos + 1 < length:
      inc(parser.pos)
      case json[parser.pos]     # Allowed escaped symbols
      of '\"', '/', '\x08', 'b', 'f', 'r', 'n', 't':
        discard
      of 'u':
        inc(parser.pos)
        var i = 0
        while i < 4 and parser.pos < length and json[parser.pos] != '\0':
          # If it isn't a hex character we have an error
          if not ((json[parser.pos] >= '0' and json[parser.pos] <= '9') or
              (json[parser.pos] >= 'A' and json[parser.pos] <= 'F') or
              (json[parser.pos] >= 'a' and json[parser.pos] <= 'f')):
            raise newException(JsmnBadTokenException, $parser)
          inc(parser.pos)
          inc(i)
        dec(parser.pos)
      else:
        raise newException(JsmnBadTokenException, $parser)
    inc(parser.pos)
  raise newException(JsmnBadTokenException, $parser)


template default(): untyped =
  parsePrimitive(parser, tokens, json, length)
  inc(count)
  if parser.toksuper != -1:
    assert tokens[parser.toksuper].kind != JSMN_STRING and tokens[parser.toksuper].kind != JSMN_PRIMITIVE
    inc(tokens[parser.toksuper].size)
  
proc parse(parser: var JsmnParser, tokens: var openarray[JsmnToken], json: string, length: int): int =
  ## Parse JSON string and fill tokens.
  if tokens.len <= 0:
    return 0
  var token: ptr JsmnToken
  var count = parser.toknext
  while parser.pos < length and json[parser.pos] != '\0':
    var kind: JsmnKind
    var c = json[parser.pos]
    case c
    of '{', '[':
      inc(count)
      token = initToken(parser, tokens)
      if parser.toksuper != -1:
        assert tokens[parser.toksuper].kind != JSMN_STRING and tokens[parser.toksuper].kind != JSMN_PRIMITIVE
        inc(tokens[parser.toksuper].size)
        when not defined(JSMN_NO_PARENT_LINKS):
          token.parent = parser.toksuper
          assert tokens[token.parent].kind != JSMN_STRING and tokens[token.parent].kind != JSMN_PRIMITIVE
      token.kind = (if c == '{': JSMN_OBJECT else: JSMN_ARRAY)
      token.start = parser.pos
      parser.toksuper = parser.toknext - 1
      assert tokens[parser.toksuper].kind != JSMN_STRING and tokens[parser.toksuper].kind != JSMN_PRIMITIVE
    of '}', ']':
      kind = (if c == '}': JSMN_OBJECT else: JSMN_ARRAY)
      when not defined(JSMN_NO_PARENT_LINKS):
        if parser.toknext < 1:
          raise newException(JsmnBadTokenException, $parser)
        token = addr tokens[parser.toknext - 1]
        while true:
          if token.start != -1 and token.stop == -1:
            if token.kind != kind:
              raise newException(JsmnBadTokenException, $parser)
            token.stop = parser.pos + 1
            parser.toksuper = token.parent
            break
          if token.parent == -1:
            break
          token = addr tokens[token.parent]
      else:
        var i = parser.toknext - 1
        while i >= 0:
          token = addr tokens[i]
          if token.start != -1 and token.stop == -1:
            if token.kind != kind:
              raise newException(JsmnBadTokenException, $parser)
            parser.toksuper = -1
            token.stop = parser.pos + 1
            break
          dec(i)
        # Error if unmatched closing bracket
        if i == -1:
          raise newException(JsmnBadTokenException, $parser)
        while i >= 0:
          token = addr tokens[i]
          if token.start != -1 and token.stop == -1:
            parser.toksuper = i
            assert tokens[parser.toksuper].kind != JSMN_STRING and tokens[parser.toksuper].kind != JSMN_PRIMITIVE
            break
          dec(i)
    of '"':
      parseString(parser, tokens, json, length)
      inc(count)
      if parser.toksuper != -1:
        assert tokens[parser.toksuper].kind != JSMN_STRING and tokens[parser.toksuper].kind != JSMN_PRIMITIVE
        inc(tokens[parser.toksuper].size)
    of '\t', '\r', '\x0A', ' ':
      discard
    of ':':
      let i = parser.toknext - 1
      if tokens[i].kind != JSMN_STRING and tokens[i].kind != JSMN_PRIMITIVE:
        parser.toksuper = i
        assert tokens[parser.toksuper].kind != JSMN_STRING and tokens[parser.toksuper].kind != JSMN_PRIMITIVE
    of ',':
      if parser.toksuper != -1 and
         tokens[parser.toksuper].kind != JSMN_ARRAY and
         tokens[parser.toksuper].kind != JSMN_OBJECT:
        when not defined(JSMN_NO_PARENT_LINKS):
          parser.toksuper = tokens[parser.toksuper].parent
        else:
          var i = parser.toknext - 1
          while i >= 0:
            if tokens[i].kind == JSMN_ARRAY or tokens[i].kind == JSMN_OBJECT:
              if tokens[i].start != -1 and tokens[i].stop == -1:
                parser.toksuper = i
                assert tokens[parser.toksuper].kind != JSMN_STRING and tokens[parser.toksuper].kind != JSMN_PRIMITIVE
                break
            dec(i)
    else:
      when defined(JSMN_STRICT):
        # In strict mode primitives are: numbers and booleans
        case c
        of '-', {'0'..'9'}, 't', 'f', 'n':
          # And they must not be keys of the object
          if tokens.len <= 0 and parser.toksuper != -1:
            var t: ptr JsmnToken = addr(tokens[parser.toksuper])
            if t.kind == JSMN_OBJECT or (t.kind == JSMN_STRING and t.size != 0):
              raise newException(JsmnBadTokenException, $parser)
          default()
        else:
          raise newException(JsmnBadTokenException, $parser)
      else:
        default()
        
    inc(parser.pos)

  var i = parser.toknext - 1
  while i >= 0:
    # Unmatched opened object or array
    if tokens[i].start != -1 and tokens[i].stop == -1:
      raise newException(JsmnNotEnoughJsonDataException, $parser)
    dec(i)
  return count

{.pop.}

proc parseJson*(json: string, tokens: var openarray[JsmnToken]): int =
  ## Parse a JSON data string into and array of tokens, each describing a single JSON object.
  var parser: JsmnParser
  parser.pos = 0
  parser.toknext = 0
  parser.toksuper = -1
  parser.parse(tokens, json, json.len)

proc parseJson*(json: string): seq[JsmnToken] =
  ## Parse a JSON data and returns a sequence of tokens
  result = newSeq[JsmnToken](JSMN_TOKENS)
  var ret = -1
  while ret < 0:
    try:
      ret = parseJson(json, result)
    except JsmnNotEnoughTokensException:
      setLen(result, result.len + JSMN_TOKENS)
    except:
      raise getCurrentException()

  setLen(result, ret)
