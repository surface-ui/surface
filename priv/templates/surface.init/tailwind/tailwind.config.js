module.exports = {
  content: [
    './js/**/*.js',
    '../lib/*_web.ex',
    '../lib/*_web/**/*.*ex',
    '../lib/*_web/**/*.sface',
    '../priv/catalogue/**/*.{ex,sface}',
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/forms')
  ]
}
