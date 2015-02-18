module.exports =

    root: ""
    base: ""

    static:
        "/": "public"
        "/test": "test/public"

    files:
        css:
            type: "css"
            target: "public/{{app.name}}.css"
            paths: { "src": "**", "srcBase": "css" }

        js:
            type: "js"
            target: "public/{{app.name}}.js"
            paths: [
              { src: "**", srcBase: "lib" },
              { src: "**", srcBase: "app", npm: true, commonjs: true }
            ]
        
        specs:
            type: "js"
            target: "test/public/specs.js",
            files: { src: "**", srcBase: "test/specs", commonjs: "specs" },

    build: [
        "compile", "npm", "commonjs", "join", "minify"
    ]

    test: [
        "karma"
    ]

    clean: [
        "clean"
    ]

    deploy: []


