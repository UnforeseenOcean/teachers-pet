SpecSuite = require './spec-suite'

module.exports =
class SpecEnvironment
  # A SpecEnvironment is a store for all the data associated with a given
  # spec run. Most notably, before a run starts, it stores the root
  # SpecSuite and keeps track of the "current" SpecSuite as `createDescribe`
  # recurses into nested `describe`s, which is necessary for the global `describe`,
  # `it`, and related functions to use to attach data at the right nesting level.
  #
  # Creating a SpecEnvironment creates a root SpecSuite automatically, so users
  # can use `it`, etc. right away without defining a `describe`.
  #
  # Finally, SpecEnvironment has a key called `publicMethods` that specifies
  # a list of method names corresponding to methods on the environment that
  # are allowed to be exported as globals for specs to use.
  constructor: (@reporter, @options={}) ->
    @running = false
    @options =
      asyncTimeout: @options.asyncTimeout ? 1000
    @userEnv = {}
    @maxFocusLevel = 0
    @rootSuite = new SpecSuite(this, '<root>')
    @suiteStack = [@rootSuite]

    for methodName in SpecEnvironment.publicMethods
      this[methodName] = this[methodName].bind(this)

  currentSuite: =>
    @suiteStack[@suiteStack.length - 1]

  pushSuite: (suite) =>
    @suiteStack.push(suite)

  popSuite: =>
    @suiteStack.pop()

  describe: (description, userOptions, subSuiteFn) =>
    @createDescribe description, userOptions, subSuiteFn, {}

  xdescribe: (description, userOptions, subSuiteFn) =>
    @createDescribe description, userOptions, subSuiteFn, pending: true

  createDescribe: (description, userOptions, subSuiteFn, options={}) ->
    throw new Error("Cannot define new describes while suite is running") if @running
    if not subSuiteFn?
      subSuiteFn = userOptions
      userOptions = {}
    subSuite = @currentSuite().describe description, userOptions, subSuiteFn, options
    @pushSuite(subSuite)
    subSuiteFn.call(@userEnv)
    @popSuite()
    subSuite

  it: (description, userOptions, itFn) =>
    @createIt description, userOptions, itFn, {}

  xit: (description, userOptions, itFn) =>
    @createIt description, userOptions, itFn, pending: true

  createIt: (description, userOptions, itFn, options={}) =>
    throw new Error("Cannot define new its while suite is running") if @running
    if not itFn?
      itFn = userOptions
      userOptions = {}

    if not itFn?
      options = Object.assign {}, options, pending: true

    @currentSuite().it description, userOptions, itFn, options

  beforeEach: (beforeFn) =>
    @currentSuite().beforeEach beforeFn

  afterEach: (afterFn) =>
    @currentSuite().afterEach afterFn

SpecEnvironment.publicMethods = [
  'describe', 'xdescribe', 'it', 'xit',
  'beforeEach', 'afterEach'
]

for baseMethodName in ["describe", "it"]
  for i in [1..6]
    do (baseMethodName, i) ->
      effs = "f".repeat(i)
      methodName = "#{effs}#{baseMethodName}"
      SpecEnvironment.prototype[methodName] = (desc, userOpt, subFn) ->
        @maxFocusLevel = Math.max @maxFocusLevel, i
        if baseMethodName is 'describe'
          @createDescribe desc, userOpt, subFn, focusLevel: i
        else if baseMethodName is 'it'
          @createIt desc, userOpt, subFn, focusLevel: i
      SpecEnvironment.publicMethods.push(methodName)
