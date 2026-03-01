module.exports = {
    root: true,
    env: {
        es6: true,
        node: true,
    },
    extends: [
        "eslint:recommended",
    ],
    rules: {
        "no-unused-vars": "warn",
        "no-undef": "warn",
        "quotes": "off",
        "semi": "off",
        "eol-last": "off",
        "max-len": "off",
        "indent": "off",
        "object-curly-spacing": "off",
        "comma-dangle": "off",
    },
    parserOptions: {
        ecmaVersion: 2018,
    },
};
