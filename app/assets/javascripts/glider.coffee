###
  glider 0.1.5 - AngularJS slider
  https://github.com/evrone/glider
  Copyright (c) 2013 Valentin Vasilyev, Dmitry Karpunin
  Licensed under the MIT (http://www.opensource.org/licenses/mit-license.php) license.

  examples:

  basic:
  <slider min="0" max="100" step="1" value="age"></slider>

  update only on mouse up:
  <slider defer_update min="0" max="100" step="1" value="age"></slider>

  show value in handle:
  <slider show_value_in_handle min="0" max="100" step="1" value="age"></slider>

  slider with increments (incompatible with step option)
  <slider min="0" max="100" increments="10,50,60,90"></slider>
###
'use strict'

gliderModule = angular.module('glider', [])

gliderModule.directive 'slider', ['$document', ($document) ->

  template: """
            <span class="g-slider horizontal">
            <span class="slider" ng-click="sliderClick($event)">
            <span class="range" ng-style="{width: xPosition+'%'}"></span>
            <span class="handle" ng-style="{left: xPosition +'%'}" ng-mousedown="handleMouseDown($event)">
            <span class="value" ng-show="showValueInHandle">{{handleValue | intersperse}}</span>
            </span>
            </span>
            <span class="side dec">
            <span class="button" ng-click="step(-1)">-</span>
            <span class="bound-value">{{min() | intersperse}}</span>
            </span>
            <span class="side inc">
            <span class="button" ng-click="step(+1)">+</span>
            <span class="bound-value">{{max() | intersperse}}</span>
            </span>
            <span class="increments">
            <span ng-repeat="i in increments" class="i" ng-style="{left: i.offset+'%'}">
            {{ i.value | intersperse }}
            </span>
            </span>
            </span>
            """

  replace: true
  restrict: "E"
  scope:
    value: "="
    min: "&"
    max: "&"
    values: "&"

  link: (scope, element, attrs) ->
    scope.parsedValues = scope.values().split(',').map((el) -> parseInt(el)) if scope.values? && scope.values()?

    bound = (value, min, max) ->
      Math.min(Math.max(min, value), max)

    parseIncrements = ->
      return unless attrs.increments?
      min = scope.min()
      max = scope.max()
      return unless isFinite(min) and isFinite(max)
      offsetK = 100 / Math.abs(max - min)
      scope.increments = []
      scope.snapValues = [min, max]
      for i in attrs.increments.split(',')
        i = parseInt(i)
        if min < i < max
          scope.increments.push value: i, offset: (i - min) * offsetK
          scope.snapValues.push i
      scope.snapValues.sort((a, b) -> a - b)

    sliderElement = element[0].getElementsByClassName('slider')[0]
    dragging = false
    scope.xPosition = 0
    step = attrs.step or 1
    deferUpdate = attrs.deferUpdate?
    scope.showValueInHandle = attrs.showValueInHandle?

    scope.value = scope.min() unless scope.value?

    refreshHandle = ->
      if scope.parsedValues?
        range = scope.parsedValues.length
        value_index = _.findIndex scope.parsedValues, (el) ->
          el >= parseInt(scope.value)
        scope.xPosition = value_index / range * 100
        scope.xPosition = bound scope.xPosition, 0, 100
      else
        range = scope.max() - scope.min()
        if range is 0
          scope.xPosition = 0
        else
          scope.xPosition = (scope.value - scope.min()) / range * 100
          scope.xPosition = bound(scope.xPosition, 0, 100)
        scope.handleValue = scope.value if scope.showValueInHandle

    snap = ->
      if scope.increments
        minDiff = Infinity
        for snapValue in scope.snapValues
          diff = Math.abs(snapValue - scope.value)
          if diff < minDiff
            minDiff = diff
            closestValue = snapValue
        scope.value = closestValue if isFinite(closestValue)

      if scope.parsedValues
        minDiff = Infinity
        for value in scope.parsedValues
          diff = Math.abs(value - scope.value)
          if diff < minDiff
            minDiff = diff
            closestValue = value
        scope.value = closestValue if isFinite(closestValue)

      refreshHandle()

    valueFromPosition = ->
      if scope.parsedValues?
        index = Math.round((scope.parsedValues.length * scope.xPosition / 100) / step) * step
        scope.parsedValues[index]
      else
        Math.round((((scope.max() - scope.min()) * (scope.xPosition / 100)) + scope.min()) / step) * step

    scope.$watch 'min()', (minValue) ->
      parseIncrements()
      scope.value = minValue if scope.value < minValue
      snap()

    scope.$watch 'max()', (maxValue) ->
      parseIncrements()
      scope.value = maxValue if scope.value > maxValue
      snap()

    scope.$watch 'value', (newVal, oldVal) ->
      return  if dragging
      if isFinite(newVal)
        if scope.min() <= newVal <= scope.max()
          refreshHandle()
        else
          scope.value = bound(newVal, scope.min(), scope.max())
      else
        scope.value = if isFinite(oldVal) then oldVal else scope.min()

    scope.step = (steps) ->
      doStep = (steps)->
        newValue = scope.value + steps * step
        if scope.min() <= newValue <= scope.max()
          scope.value = newValue

      doIncrement = (steps) ->
        newVal = if steps > 0
          (sv for sv in scope.snapValues when sv > scope.value)[0]
        else
          (sv for sv in scope.snapValues when sv < scope.value).reverse()[0]
        scope.value = newVal if newVal?

      doValueStep = (steps) ->
        index = if steps > 0
          _.findIndex scope.parsedValues, (el) ->
            el >= scope.value
        else
          _.findLastIndex scope.parsedValues, (el) ->
            el <= scope.value

        index = 0 if index == -1
        newVal = scope.parsedValues[ Math.min(index + steps, scope.parsedValues.length-1) ]
        scope.value = newVal if newVal?

      if attrs.increments?
        doIncrement steps
      else if scope.parsedValues?
        doValueStep steps
      else
        doStep steps

    scope.sliderClick = ($event) ->
      return if angular.element($event.target).hasClass('handle')
      offsetX = $event.layerX ? $event.originalEvent?.layerX
      scope.xPosition = offsetX / sliderElement.offsetWidth * 100
      scope.value = valueFromPosition()
      snap()

    startPointX = null

    scope.handleMouseDown = ($event) ->
      return unless angular.element($event.target).hasClass('handle')
      startPointX = $event.pageX
      dragging = true

    $document.on 'mousemove', ($event) ->
      return  unless dragging
      moveDelta = $event.pageX - startPointX
      scope.xPosition += moveDelta / sliderElement.offsetWidth * 100
      if scope.xPosition < 0
        scope.xPosition = 0
      else if scope.xPosition > 100
        scope.xPosition = 100
      else
        startPointX = $event.pageX
      scope.value = valueFromPosition() unless deferUpdate
      scope.handleValue = valueFromPosition() if scope.showValueInHandle
      scope.$apply()

    $document.on 'mouseup', ->
      return  unless dragging
      scope.value = valueFromPosition() if deferUpdate
      snap()
      scope.$apply()
      dragging = false
]



gliderModule.filter 'intersperse', ->
  (input) ->
    return unless input?
    input = input.toString()
    reverseString = (input) -> input.split('').reverse().join('')
    reversed = reverseString(input)
    reversed = reversed.replace(/(.{3})/g, '$1 ')
    sliced = reverseString(reversed)
    sliced.trim()
