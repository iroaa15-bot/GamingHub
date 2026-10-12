# Daily challenge deployment

1. Generate a daily image and puzzle using the local project generator.
2. Review the image, verify the answer, and approve the content.
3. Put the approved `daily.json` and matching `daily-YYYY-MM-DD.png` into the `docs/` folder.
4. Configure GitHub Pages to deploy from the `main` branch `/docs` folder.
5. Set the Godot DailyAI `base_url` to `https://iroaa15-bot.github.io/GamingHub` after the first successful deployment.

**Security:** Do not put image generation API keys into the public repository. This is review-first publishing, not unattended AI generation.
