spawn = require('child_process').spawn
{createInterface} = require('readline')

module.exports = AtomMerlinOcaml =
  merlin: null

  activate: (state) ->
    @startMerlinProcess()

  deactivate: ->
    @merlin.kill()

  startMerlinProcess: ->
    @merlin = spawn 'ocamlmerlin', []
    console.log "Merlin process started, pid = #{@merlin.pid}"
    @merlin.on 'exit', (code) -> console.log "Merlin exited with code #{code}"

  queryMerlin: (query) ->
    stdin = @merlin.stdin
    stdout = @merlin.stdout
    new Promise (resolve, reject) =>
      reader = createInterface({
        input: stdout,
        terminal: false,
      })

      reader.on 'line', (line) =>
        reader.close()
        [kind, payload] = JSON.parse(line)
        if kind == "return"
          resolve payload
        else
          console.error "Merlin returned error response"
          reject(Error(line))

      jsonQuery = JSON.stringify(query)
      stdin.write jsonQuery

  provideLinter: ->
    name: 'OCaml Linter'
    grammarScopes: ['source.ocaml']
    scope: 'file'
    lintOnFly: false
    lint: (editor) =>
      filePath = editor.getPath()
      new Promise (resolve, reject) =>
        @queryMerlin({"context": ["auto", filePath], "query": ["tell", "start", "at", {"line":1, "col":0}]}).then =>
          @queryMerlin({"context": ["auto", filePath], "query": ["tell", "file-eof", filePath]}).then =>
            @queryMerlin({"context": ["auto", filePath], "query": ["errors"]}).then (payload) =>
              errors = []
              for e in payload
                err =
                  type: if e.type == 'Warning' then 'Warning' else 'Error'
                  text: e.message
                  range: [[e.start.line-1,e.start.col],[e.end.line-1,e.end.col]]
                  filePath: filePath
                errors.push err
              resolve(errors)
