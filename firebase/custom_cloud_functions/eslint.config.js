const js = require("@eslint/js");
const globals = require("globals");
const {defineConfig, globalIgnores} = require("eslint/config");

module.exports = defineConfig([
  globalIgnores([
    "node_modules/**",
    ".npm-cache/**",
    "coverage/**",
  ]),
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: "commonjs",
      globals: globals.node,
    },
    linterOptions: {
      reportUnusedDisableDirectives: "error",
    },
    rules: {
      ...js.configs.recommended.rules,
      "eqeqeq": ["error", "always", {null: "ignore"}],
      "no-console": "off",
      "no-duplicate-imports": "error",
      "no-promise-executor-return": "error",
      "no-template-curly-in-string": "error",
      "no-unreachable-loop": "error",
      "no-unused-vars": [
        "error",
        {
          args: "after-used",
          argsIgnorePattern: "^_",
          caughtErrors: "none",
          varsIgnorePattern: "^_",
        },
      ],
      "no-useless-call": "error",
      "no-useless-concat": "error",
      "no-useless-return": "error",
      "prefer-promise-reject-errors": "error",
    },
  },
]);
