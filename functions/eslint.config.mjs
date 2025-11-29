import {FlatCompat} from "@eslint/eslintrc";
import js from "@eslint/js";
import path from "node:path";
import {fileURLToPath} from "node:url";
import globals from "globals";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const compat = new FlatCompat({
  baseDirectory: __dirname,
  recommendedConfig: js.configs.recommended,
  allConfig: js.configs.all,
});

export default [
  {
    ignores: ["lib/**/*", ".eslintrc.js"],
  },
  ...compat.extends(
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "plugin:@typescript-eslint/recommended",
  ),
  {
    files: ["**/*.ts", "**/*.js"],
    languageOptions: {
      parserOptions: {
        project: ["tsconfig.eslint.json"],
        sourceType: "module",
      },
      globals: {
        ...globals.node,
        ...globals.es2021,
      },
    },
    rules: {
      quotes: ["error", "double"],
      "import/no-unresolved": 0,
      indent: ["error", 2],
      "max-len": ["error", {code: 150}],
      "@typescript-eslint/no-explicit-any": "off",
      "@typescript-eslint/no-unused-vars": "off",
    },
  },
];
