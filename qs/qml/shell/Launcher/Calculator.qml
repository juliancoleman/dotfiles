pragma Singleton

import QtQuick
import Quickshell

// Evaluates arithmetic typed into the launcher, including the ways people say it: "15% of 30", "20% off 50",
// "50 + 10%", "3 times 4", "square root of 2". A small parser of its own; nothing typed is ever run as code.
Singleton {
    id: root

    readonly property var functions: ({
        sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, ln: Math.log, log: Math.log10, exp: Math.exp,
        sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan,
        round: Math.round, floor: Math.floor, ceil: Math.ceil
    })
    readonly property var constants: ({ pi: Math.PI, "π": Math.PI, e: Math.E, tau: 2 * Math.PI })

    // Spoken forms become symbols before tokenizing; longer phrases first so "divided by" beats "by".
    readonly property var phrases: [
        [/\bsquare root of\b/g, " sqrt "], [/\bcube root of\b/g, " cbrt "], [/\b(?:sqrt|root) of\b/g, " sqrt "],
        [/\bto the power of\b/g, " ^ "], [/\b(?:multiplied by|times)\b/g, " * "], [/\bdivided by\b/g, " / "],
        [/\bover\b/g, " / "], [/\bplus\b/g, " + "], [/\bminus\b/g, " - "], [/\bsquared\b/g, " ^ 2 "],
        [/\bcubed\b/g, " ^ 3 "], [/\bpercent\b/g, " % "], [/\bof\b/g, " * "],
        [/[×✕]/g, " * "], [/÷/g, " / "], [/[−–]/g, " - "], [/\*\*/g, " ^ "]
    ]

    // { value, text, copy } for a query that computes something, otherwise null.
    function evaluate(query) {
        const tokens = tokenize(String(query || ""))
        if (!tokens || !tokens.some(t => t.op || t.fn) || !tokens.some(t => t.num !== undefined))
            return null
        const state = { tokens: tokens, at: 0 }
        let result
        try {
            result = expression(state)
        } catch (error) {
            return null
        }
        if (state.at !== tokens.length || !isFinite(result.value))
            return null
        const value = Number(result.value.toPrecision(12))
        return { value: value, text: display(value), copy: plain(value) }
    }

    function tokenize(source) {
        let text = source.toLowerCase().replace(/(\d),(?=\d{3}\b)/g, "$1")
            .replace(/^\s*(?:(?:what(?:'s| is)|calculate)\s+|=\s*)/, "").replace(/[?=]\s*$/, "")
        for (const [pattern, symbol] of phrases)
            text = text.replace(pattern, symbol)
        // "3 x 4" and "3x4" multiply; a lone x elsewhere isn't arithmetic.
        text = text.replace(/(\d|\))\s*x\s*(?=[\d(.])/g, "$1 * ")
        text = text.trim()
        const out = []
        const pattern = /\s*(?:(\d+\.?\d*(?:e[+-]?\d+)?|\.\d+)|([a-zπ]+)|(\S))/g
        let at = 0
        while (at < text.length) {
            pattern.lastIndex = at
            const match = pattern.exec(text)
            if (!match || match.index !== at)
                return null
            at = pattern.lastIndex
            if (match[1] !== undefined) {
                out.push({ num: parseFloat(match[1]) })
            } else if (match[2] !== undefined) {
                const word = match[2]
                if (constants[word] !== undefined)
                    out.push({ num: constants[word] })
                else if (functions[word] !== undefined)
                    out.push({ fn: word })
                else if (word === "mod" || word === "off")
                    out.push({ op: word })
                else
                    return null
            } else if ("+-*/^%!()".includes(match[3])) {
                out.push(match[3] === "(" || match[3] === ")" ? { paren: match[3] } : { op: match[3] })
            } else {
                return null
            }
        }
        return out.length ? out : null
    }

    function peek(state) {
        return state.tokens[state.at]
    }

    function take(state) {
        return state.tokens[state.at++]
    }

    function isOp(token, op) {
        return !!token && token.op === op
    }

    // Results are { value, percent }: a percentage stays marked until something other than + - "off" uses it.
    function expression(state) {
        let left = term(state)
        while (isOp(peek(state), "+") || isOp(peek(state), "-")) {
            const sign = take(state).op === "+" ? 1 : -1
            const right = term(state)
            // "50 + 10%" is fifty plus ten percent of fifty.
            const amount = right.percent ? left.value * right.value : right.value
            left = { value: left.value + sign * amount, percent: false }
        }
        return left
    }

    function term(state) {
        let left = unary(state)
        for (;;) {
            const next = peek(state)
            if (isOp(next, "*") || isOp(next, "/") || isOp(next, "mod") || isOp(next, "off")) {
                const op = take(state).op
                const right = unary(state)
                if (op === "*")
                    left = { value: left.value * right.value, percent: false }
                else if (op === "/")
                    left = { value: left.value / right.value, percent: false }
                else if (op === "mod")
                    left = { value: left.value % right.value, percent: false }
                else if (left.percent)
                    left = { value: right.value * (1 - left.value), percent: false }
                else
                    throw new Error("off needs a percentage")
            } else if (next && (next.paren === "(" || next.fn || next.num !== undefined)) {
                // Implicit multiplication: "2(3+4)", "2pi", "3 sqrt 4".
                const right = unary(state)
                left = { value: left.value * right.value, percent: false }
            } else {
                return left
            }
        }
    }

    function unary(state) {
        if (isOp(peek(state), "-")) {
            take(state)
            const inner = unary(state)
            return { value: -inner.value, percent: inner.percent }
        }
        if (isOp(peek(state), "+")) {
            take(state)
            return unary(state)
        }
        return power(state)
    }

    function power(state) {
        const base = postfix(state)
        if (!isOp(peek(state), "^"))
            return base
        take(state)
        const exponent = unary(state)
        return { value: Math.pow(base.value, exponent.value), percent: false }
    }

    function postfix(state) {
        let result = primary(state)
        for (;;) {
            if (isOp(peek(state), "%")) {
                take(state)
                result = { value: result.value / 100, percent: true }
            } else if (isOp(peek(state), "!")) {
                take(state)
                result = { value: factorial(result.value), percent: false }
            } else {
                return result
            }
        }
    }

    function primary(state) {
        const token = take(state)
        if (!token)
            throw new Error("expected a number")
        if (token.num !== undefined)
            return { value: token.num, percent: false }
        if (token.fn)
            return { value: functions[token.fn](postfix(state).value), percent: false }
        if (token.paren === "(") {
            const inner = expression(state)
            const close = take(state)
            if (!close || close.paren !== ")")
                throw new Error("expected )")
            return { value: inner.value, percent: inner.percent }
        }
        throw new Error("unexpected token")
    }

    function factorial(n) {
        if (n < 0 || n > 170 || Math.floor(n) !== n)
            return NaN
        let out = 1
        for (let i = 2; i <= n; ++i)
            out *= i
        return out
    }

    function plain(value) {
        const magnitude = Math.abs(value)
        if (magnitude !== 0 && (magnitude >= 1e15 || magnitude < 1e-6))
            return value.toExponential().replace(/\.?0+e/, "e")
        return String(value)
    }

    // Grouped for reading; the copied value stays plain.
    function display(value) {
        const text = plain(value)
        if (text.includes("e"))
            return text.replace("e+", " × 10^").replace("e", " × 10^")
        const [whole, fraction] = text.split(".")
        const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
        return fraction ? grouped + "." + fraction : grouped
    }
}
