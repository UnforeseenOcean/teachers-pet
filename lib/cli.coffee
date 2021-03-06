{Buffer} = require 'buffer'
fs = require 'fs'
path = require 'path'
vm = require 'vm'

coffee = require 'coffee-script'
yargs = require 'yargs'

SpecEnvironment = require './spec-environment'
SpecRunner = require './spec-runner'

loadSpecFile = (specFile, vmContext) ->
  filePath = path.resolve(specFile)
  code = fs.readFileSync(filePath, 'utf8')
  if path.extname(specFile) is ".coffee"
    # If we're running CoffeeScript specs, we need to compile
    # them first. We also want to embed the source map so
    # errors point to the right CS source line.
    {js, v3SourceMap} = coffee.compile(code, sourceMap: true)
    b64 = new Buffer(v3SourceMap).toString('base64')
    uri = "data:application/json;charset=utf-8;base64,#{b64}"
    code = "#{js}\n//@ sourceMappingURL=#{uri}"
  script = new vm.Script(code, filename: specFile)
  script.runInContext vmContext

createContext = (env) ->
  newExports = {}
  newModule =
    exports: newExports

  envApi = {}
  envApi[item] = env[item] for item in SpecEnvironment.publicMethods

  safeContext = Object.assign {}, global, envApi,
    require: require,
    exports: newExports,
    module: newModule,
  vm.createContext safeContext

getReporterByName = (name = "default") ->
  file = path.join(__dirname, 'reporters', "#{name}-reporter")
  require file



argv = yargs
  .usage('Usage: $0 [options] [test files...]')
  .alias('t', 'async-timeout')
  .nargs('t', 1)
  .default('t', 1000)
  .describe('t', 'how long to wait (in ms) for async tests to finish')
  .alias('o', 'reporter')
  .choices('o', ['dots', 'bdd'])
  .default('o', 'dots')
  .describe('o', 'which test reporter to use')
  .describe('no-color', 'disable color output')
  .help('h')
  .alias('h', 'help')
  .argv

specFiles = argv._
reporter = argv.reporter
asyncTimeout = argv.asyncTimeout

if not specFiles.length
  console.error "No spec files specified"
  process.exit 1

SpecReporter = getReporterByName argv.reporter
reporter = new SpecReporter()
env = new SpecEnvironment(reporter, asyncTimeout: asyncTimeout)
runner = new SpecRunner(env)
context = createContext(env)
loadSpecFile spec, context for spec in specFiles
runOptions =
  onSuiteStart: reporter.onSuiteStart
  onSuiteEnd: reporter.onSuiteEnd
  onSpecStart: reporter.onSpecStart
  onSpecEnd: reporter.onSpecEnd
runner.run(runOptions)
  .then (code) ->
    reporter.report(env)
    process.exit(code)
