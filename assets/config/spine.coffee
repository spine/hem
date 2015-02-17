module.exports =

    "settings": 
        "root": ""
        "base": ""
        "static": 
            "/": "public"
            "/test": "test/public"

    "files":
        "applicationcss":
            "type": "css"
            "target": "public/{{app.name}}.css"
            "paths": { "src": "**", "srcBase": "css" }

        "applicationjs": 
            "type": "js"
            "target": "public/{{app.name}}.js"
            "paths": [
              { "src": "**", "srcBase": "lib" },
              { "src": "**", "srcBase": "app", "npm": true, "commonjs": true }
            ]
        
        "specs":
            "type": "js"
            "target": "test/public/specs.js",
            "files": { "src": "**", "srcBase": "test/specs" },

    "build": [
        "compile", "npm", "commonjs", "join", "minify"
    ]

    "test": [
        "karma"
    ]

    "clean": [
        "clean"
    ]

    "deploy": []


