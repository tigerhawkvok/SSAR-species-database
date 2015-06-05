#spawn = require('child_process').spawn
#require("load-grunt-tasks")(grunt)

module.exports = (grunt) ->
  # Gruntfile
  # https://github.com/sindresorhus/grunt-shell
  grunt.loadNpmTasks("grunt-shell")
  # https://www.npmjs.com/package/grunt-contrib-coffee
  grunt.loadNpmTasks("grunt-contrib-coffee")
  # https://github.com/gruntjs/grunt-contrib-watch
  grunt.loadNpmTasks("grunt-contrib-watch")
  grunt.loadNpmTasks("grunt-contrib-uglify")
  grunt.loadNpmTasks("grunt-contrib-cssmin")
  # Validators
  grunt.loadNpmTasks('grunt-bootlint')
  grunt.loadNpmTasks('grunt-html')
  grunt.loadNpmTasks('grunt-string-replace')
  grunt.loadNpmTasks('grunt-postcss')
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')
    shell:
      options:
        stderr: false
      bower:
        command: ["bower update"].join("&&")
      npm:
        command: ["npm update"].join("&&")
      movesrc:
        command: ["mv js/c.src.coffee js/maps/c.src.coffee"].join("&&")
      vulcanize:
        # Should also use a command to replace js as per uglify:vulcanize
        command: ["vulcanize --csp -o app-prerelease.html --strip app.html"].join("&&")
    'string-replace':
      vulcanize:
        options:
          replacements: [
            pattern: "app-prerelease.js",
            replacement: "js/app.min.js"
            ]
        files:
          "index.html":"app-prerelease.html"
    postcss:
      options:
        processors: [
          require('autoprefixer-core')({browsers: 'last 1 version'})
          ]
      dist:
        src: "css/main.css"
      drop:
        src: "css/shadow-dropzone.css"
    uglify:
      options:
        mangle:
          except:['jQuery']
      vulcanize:
        options:
          sourceMap:true
          sourceMapName:"js/maps/app.js.map"
        files:
          "js/app.min.js":["app-prerelease.js"]
      combine:
        options:
          sourceMap:true
          sourceMapName:"js/maps/combined.map"
          sourceMapIncludeSources:true
          sourceMapIn:"js/maps/c.js.map"
        files:
          "js/combined.min.js":["js/c.js","bower_components/purl/purl.js","bower_components/xmlToJSON/lib/xmlToJSON.js","bower_components/jquery-cookie/jquery.cookie.js"]
      dist:
        options:
          sourceMap:true
          sourceMapName:"js/maps/c.map"
          sourceMapIncludeSources:true
          sourceMapIn:"js/maps/c.js.map"
          compress:
            # From https://github.com/mishoo/UglifyJS2#compressor-options
            dead_code: true
            unsafe: true
            conditionals: true
            unused: true
            loops: true
            if_return: true
            drop_console: false
            warnings: true
            properties: true
            sequences: true
            cascade: true
        files:
          "js/c.min.js":["js/c.js"]
      minpurl:
        options:
          sourceMap:true
          sourceMapName:"js/maps/purl.map"
        files:
          "js/purl.min.js": ["bower_components/purl/purl.js"]
      minxmljson:
        options:
          sourceMap:true
          sourceMapName:"js/maps/xmlToJSON.map"
        files:
          "js/xmlToJSON.min.js": ["bower_components/xmlToJSON/lib/xmlToJSON.js"]
      minjcookie:
        options:
          sourceMap:true
          sourceMapName:"js/maps/jquery.cookie.map"
        files:
          "js/jquery.cookie.min.js": ["bower_components/jquery-cookie/jquery.cookie.js"]
    cssmin:
      options:
        sourceMap: true
        advanced: false
      target:
        files:
          "css/main.min.css":["css/main.css"]
          "css/dropzone.min.css":["css/shadow-dropzone.css"]
    coffee:
      compile:
        options:
          bare: true
          join: true
          sourceMapDir: "js/maps"
          sourceMap: true
        files:
          "js/c.js":"coffee/*.coffee"
    watch:
      scripts:
        files: ["coffee/*.coffee"]
        tasks: ["coffee:compile","uglify:dist","shell:movesrc"]
      styles:
        files: ["css/main.css"]
        tasks: ["postcss","cssmin"]
      html:
        files: ["app.html"]
        tasks: ["bootlint","shell:vulcanize","uglify:vulcanize","string-replace:vulcanize"]
    bootlint:
      options:
        stoponerror: false
        relaxerror: ['W009']
      files: ["index.html","admin-page.html"]
    htmllint:
      all:
        src: ["index.html","admin-page.html"]
        ignore: [/XHTML element “[a-z-]+” not allowed as child of XHTML element.*/]
  ## Now the tasks
  grunt.registerTask("default",["watch"])
  grunt.registerTask("vulcanize","Vulcanize web components",["shell:vulcanize","uglify:vulcanize","string-replace:vulcanize"])
  grunt.registerTask("compile","Compile coffeescript",["coffee:compile","uglify:dist","shell:movesrc"])
  ## The minification tasks
  # Part 1
  grunt.registerTask("minifyIndependent","Minify Bower components that aren't distributed min'd",["uglify:minpurl","uglify:minxmljson","uglify:minjcookie"])
  # Part 2
  grunt.registerTask("minifyBulk","Minify all the things",["uglify:combine","uglify:dist","postcss","cssmin"])
  # Main call
  grunt.registerTask "minify","Minify all the things",->
    grunt.task.run("minifyIndependent","minifyBulk")
  ## Global update
  # Bower
  grunt.registerTask("updateBower","Update bower dependencies",["shell:bower"])
  grunt.registerTask("updateNPM","Update Node dependencies",["shell:npm"])
  # Minify the bower stuff in case it changed
  grunt.registerTask "update","Update dependencies", ->
    grunt.task.run("updateNPM","updateBower","minify")
  ## Deploy
  grunt.registerTask "build","Compile and update, then watch", ->
    # ,"vulcanize"
    grunt.task.run("updateNPM","updateBower","compile","minify")
