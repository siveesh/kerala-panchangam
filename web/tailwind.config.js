/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        kerala: {
          50:  '#f0f7f4',
          100: '#d9ede5',
          200: '#b4dacb',
          300: '#84c0a8',
          400: '#52a083',
          500: '#2e8362',
          600: '#1a6b4e',
          700: '#145640',
          800: '#114534',
          900: '#0d3628',
          950: '#071e17',
        },
      },
      fontFamily: {
        sans: ['"Noto Sans"', '"Noto Sans Malayalam"', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
