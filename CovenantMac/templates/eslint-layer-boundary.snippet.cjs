// Layer-boundary lint supplement — JS/TS services/application layer.
//
// Supplements covenant.sh's STEP 6.5 grep-based layer boundary scan with
// ESLint's native `no-restricted-imports` rule (built-in, AST-based — not a
// custom plugin). Verified empirically against eslint@8.57.1:
//
//   import express from "express"                -> flagged
//   import { Router as R } from "express"         -> flagged (aliasing doesn't hide it)
//   import SubRouter from "express/lib/router"    -> flagged (patterns glob catches submodules)
//   import { Controller, Get } from "@nestjs/common" -> flagged (named-import ban)
//   import { Injectable } from "@nestjs/common"   -> NOT flagged (only the HTTP-decorator
//                                                     names are banned, not the whole package)
//
// KNOWN GAPS — both disclosed in docs/SECURITY_POSTURE.md section 7, neither
// is closed by this file:
//
//   1. Re-exports: `import { raiseHttpError } from "./http_shim"` where
//      http_shim.js itself imports express is NOT caught. no-restricted-imports
//      only sees the import path written in the file being linted — it does
//      not resolve where an imported NAME is actually defined. Closing that
//      needs import-graph/AST resolution across files (the MCP graph
//      server's job), matching the pinned Python case at
//      tests/covenant/layer_boundary_block.bats:63.
//   2. CommonJS require(): `const x = require("express")` is NOT caught —
//      no-restricted-imports only inspects ES import declarations. A stack
//      still on require() needs the (deprecated but still functional)
//      no-restricted-modules rule added alongside this one.
//
// This is a snippet, not a standalone loadable config — merge the object(s)
// below into the target repo's actual ESLint config at init time:
//   - Legacy (.eslintrc.json/.js): push LAYER_BOUNDARY_OVERRIDE into your
//     top-level `overrides` array.
//   - Flat config (eslint.config.js, ESLint 9+): spread
//     LAYER_BOUNDARY_FLAT_CONFIG into your exported config array.
// Adjust FILE_GLOBS and the banned-import list to match the target stack's
// actual layer directory names and HTTP framework.

const FILE_GLOBS = [
  "services/**/*.js", "services/**/*.ts",
  "application/**/*.js", "application/**/*.ts",
];

const NO_RESTRICTED_IMPORTS_RULE = ["error", {
  paths: [
    { name: "express", message: "HTTP framework imports belong in routes/, not services/." },
    { name: "fastify", message: "HTTP framework imports belong in routes/, not services/." },
    {
      name: "@nestjs/common",
      importNames: ["Controller", "Get", "Post", "Put", "Delete", "Patch"],
      message: "HTTP decorators belong in routes/, not services/.",
    },
  ],
  patterns: ["express/*", "fastify/*"],
}];

const LAYER_BOUNDARY_OVERRIDE = {
  files: FILE_GLOBS,
  rules: { "no-restricted-imports": NO_RESTRICTED_IMPORTS_RULE },
};

const LAYER_BOUNDARY_FLAT_CONFIG = {
  files: FILE_GLOBS,
  rules: { "no-restricted-imports": NO_RESTRICTED_IMPORTS_RULE },
};

module.exports = { FILE_GLOBS, NO_RESTRICTED_IMPORTS_RULE, LAYER_BOUNDARY_OVERRIDE, LAYER_BOUNDARY_FLAT_CONFIG };
