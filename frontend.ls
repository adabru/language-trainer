ReactDOM = require 'react-dom'
React = require 'react'
{ div, span, h1 } = (require 'hyperscript-helpers') React.createElement

class CardBox extends React.Component
  displayName: '_Slides'
  render: ->
    span do
      className: 'yeah'
      'hi'

exports <<<
  render: (node) ->
    ReactDOM.render React.createElement(CardBox, {}), node
