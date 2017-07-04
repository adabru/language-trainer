#!/usr/bin/env lsc

#
# profile['یک'] =
#  * time: 1274681566, error: no, speed: 125.5
#  * time: 1274619876, error: yes, speed: 145
#  * ... (ringbuffer n=10)
#

require! [fs,util]
abp = require 'adabru-parser'

log = console.log
print = (o, d=10) ->
  console.log util.inspect o, {colors: true, depth: d}
stackTrace = (e) ->
  console.log "\033[31m#{e.stack}\033[39m"
util.flatten = (arr) -> [].concat.apply [], arr
promiseThenCatch = (p, t, c) -> p.then(t).catch(c)

algo = new
  init_vocabulary = new Promise (fulfill, reject) ->
    (err, v) <~ fs.readFile './data/vocabulary', 'utf8', _
    if err? then throw err
    (err, g) <~ fs.readFile './data/vocabulary.grammar', 'utf8', _
    if err? then throw err
    g_ast <~ (abp.parseGrammar g).then _
    v_ast <~ (abp.parse v, g_ast).then _
    fulfill do
      words : (f = (ast) -> switch ast.name
        case 'Vocab' then util.flatten ast.children.map f
        case 'Subject' then ast.children.map(f).filter (c) -> c?
        case 'Word' then trans: ast.children.0.children.0, farsi: ast.children.1.children.0, latin: f(ast.children.2)
        case 'LatinArr' then ast.children.map (c) -> c.children.0
        default then null
      ) v_ast
      phrases : (f = (ast) -> switch ast.name
        case 'Vocab' then util.flatten ast.children.map f
        case 'Subject' then ast.children.map(f).filter (c) -> c?
        case 'Phrase' then ast.children.map f
        case 'Flexed' then [ast.children.0.children.0, ast.children.1.children.0]
        case 'Farsi' then [ast.children.0, ast.children.0]
        default then null
      ) v_ast

  init_profile = new Promise (fulfill, reject) ->
    (err, p) <~ fs.readFile './data/profile.json', 'utf8', _
    if err? and err.code isnt 'ENOENT' then throw err
    fulfill if p? then JSON.parse p else {}

  @init = new Promise (fulfill, reject) ~>
    values <~ (Promise.all [init_vocabulary, init_profile]).then _
    @vocabulary = values.0
    @profile = values.1
    fulfill!

  @update = (farsi, speed, error, p=@profile) ->
    p[farsi] ?= new Array 10
    p[farsi].shift! ; p[farsi].push {speed, error, time:Date.now!}
    fs.writeFile './data/profile.json', JSON.stringify(p,void,' '), (err) -> if err? then stackTrace err

  @weight = (x) ->
    # speed of last three accesses
    30 * (((x[*-1]?.speed ? 0) * 0.5 + (x[*-2]?.speed ? 0) * 0.3 + (x[*-3]?.speed ? 0) * 0.2) / 250 <? 1) +
    # number of accesses
    20 * x.filter((a) -> a?).length / x.length +
    # error rate
    40 * x.filter((a) -> a? and not a.error).length / x.length +
    # passed time since last access
    10 * ((1 - (Date.now! - (x[*-1]?.time ? 0)) / (3*30*7*24*60*60*1000)) >? 0)

  @next_phrase = (v=@vocabulary, p=@profile, weight=@weight) ->
    # find a light word
    w_sorted = v.words.map((w,i) -> [i, weight (p[w.farsi] ?= new Array 10)]).sort (k,l) -> k.1 - l.1
    range = switch (w_sorted.findIndex (x) -> x > 0.1)
      case -1 then w_sorted.length
      default then that
    word = v.words[w_sorted[Math.floor (Math.random! * range)].0].farsi

    # find a suiting phrase
    p_choice = v.phrases.filter (p) -> p.some (x) -> x.1 is word
    phrase = switch
      case p_choice.length > 0 then p_choice[Math.floor (Math.random! * p_choice.length)]
      default then [[word,word]]

    # decorate the phrase
    phrase = phrase.map (x) ->
      w = v.words.find((a) -> a.farsi is x.1)
      if not w? then log "\033[33mFarsi word \033[1m#{x.1}\033[22m is referenced but not in the vocabulary\033[39m"
      { farsi: x.0, stem: x.1 } <<< if w? then { w.trans, w.latin, weight: weight p[x.1] }
    print phrase

# tests
if process.argv.1.endsWith 'algorithm.ls'
  <- promiseThenCatch algo.init, _, stackTrace
  print algo.next_phrase!
  e = time: Date.now!, speed: 250, error: false
  print algo.weight [e, e, e]
  print algo.weight [e, e, ({}<<<e<<< time: Date.now! - 3*30*7*24*60*60*1000 / 2)]
  print algo.weight [e, e, ({}<<<e<<< time: Date.now! - 3*30*7*24*60*60*1000 * 2)]
  print algo.weight [({}<<<e<<< error: true), e, e, e]
  print algo.weight [null,null,null,e,e,e]
  print algo.weight [null,null,null]
  # (require './absh.ls').absh p:v.phrases
