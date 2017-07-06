#!/usr/bin/env lsc

ReactDOM = require 'react-dom'
React = require 'react'
{ div, span, h1 } = (require 'hyperscript-helpers') React.createElement

class CardBox extends React.Component
  displayName: '_CardBox'
  ~>
    @state =
      phrase: []
      typed: ''
      typeStart: 0
      error: false
    window.document.addEventListener 'keydown', (event) ~>
      switch
        case event.key is 'Backspace' and event.ctrlKey
          @setState typed: ''
        case event.key is 'Backspace'
          @setState error: yes, typed: @state.typed.slice 0,-1
        case 'ا' <= event.key <= 'ی'
          if @state.typed is '' then @setState typeStart: Date.now!
          @setState typed: @state.typed + event.key
          <~ setTimeout _
          farsi = @state.phrase.find((w) -> w.train).farsi
          if @state.typed is farsi then @complete farsi, farsi.length / ((Date.now! - @state.typeStart)/(1000*60)), @state.error, @state.typeStart
    @nextPhrase!
  render: ~>
    div {className: 'cardbox'},
      [React.createElement(Word, {typed:@state.typed, key} <<< w) for w,key in @state.phrase]
  complete: (farsi,speed,error,time) ~>
    time = Date.now!
    fetch 'word', {method:'put', body:JSON.stringify {farsi,speed,error,time}}
    .then ~> setTimeout @nextPhrase, 200
  nextPhrase: ~>
    console.log 'next'
    fetch 'phrase', method: 'get'
    .then (r) ~> r.json!
    .then (d) ~> @setState phrase: d, error: no, typed: ''

# farsi: 'یک', +input, latin:['eins','ein']
class Word extends React.Component
  displayName: '_Word'
  levenshtein: (s,t) -> # smallest edit from s to t
    # cost[i,j].v = levenshtein s[0..i], t[0..j]
    cost = [[v:0, ops:[]]]
    for i from 1 to s.length then cost[i]= [v:i, ops: cost[i-1][0].ops ++ ['d']]
    for j from 1 to t.length then cost[0][j] = v:j, ops: cost[0][j-1].ops ++ ['i']
    for i from 1 to s.length
      for j from 1 to t.length
        cost[i][j] = let (
          sub = cost[i-1][j-1].v + if s[i-1] == t[j-1] then 0 else 1,
          ins = cost[i][j-1].v + 1,
          del = cost[i-1][j].v + 1
          )
          switch
            case ins <= del and ins <= sub then v:ins, ops:cost[i][j-1].ops ++ ['i']
            case del <= sub and del <= ins then v:del, ops:cost[i-1][j].ops ++ ['d']
            case sub <= ins and sub <= del then v:sub, ops:cost[i-1][j-1].ops ++ ['s']
    cost[*-1][*-1]
  render: ~>
    div {className: 'word'}, switch
      case @props.train and @props.typed is ''
        span {className: 'trans'}, @props.trans
      case @props.train
        [s, t] = [@props.typed, @props.farsi]
        edit = (@levenshtein s, t).ops
        key = 0
        while edit.length
          step = switch
            case edit.0 is 's' and s[0] is t[0]
              l = (-> (for j from 0 til s.length then if s[j] isnt t[j] then return j) ; s.length)!
              [l, l, (s.slice 0,l), 's_ok']
            case edit.0 is 's' and s[0] isnt t[0]
              [1, 1, s[0], 's_wrong']
            case edit.0 is 'i'
              [0, 1, '•', 'i']
            case edit.0 is 'd'
              [1, 0, s[0], 'd']
          [s, t] = [(s.slice step.0), (t.slice step.1)]
          edit = edit.slice step.2.length
          span {className: step.3, key:key+=1}, step.2
      default
        span {}, @props.farsi

exports <<<
  render: (node) ->
    ReactDOM.render React.createElement(CardBox), node


if process.argv.1?.endsWith 'frontend.ls'
  Word.prototype.levenshtein process.argv[2], process.argv[3]
