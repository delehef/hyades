// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration
module.exports = {
  content: [
    './js/**/*.js',
    '../lib/*_web.ex',
    '../lib/*_web/**/*.*ex'
  ],
  theme: {
      container: {
          center: true,
          padding: "2rem",
      }
  },
  plugins: [
    require('@tailwindcss/forms')
  ]
}
