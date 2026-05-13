RecordingStudioPublishable install complete.

Next steps:

1. Review `config/initializers/recording_studio_publishable.rb` and wire the current actor plus parent-recording authorization.
2. If you use environment-specific settings, create `config/recording_studio_publishable.yml`.
3. Install the engine migrations with `bin/rails generate recording_studio_publishable:migrations`.
4. Apply the migrations with `bin/rails db:migrate`.
5. Mount the engine at `/` if you want the default public route `/published/:uuid/:slug`.
6. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
