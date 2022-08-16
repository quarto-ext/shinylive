#!/usr/bin/env python3

import shutil
import os
import shiny

# Continue past this part only if building entire site.
if not os.getenv("QUARTO_PROJECT_RENDER_ALL"):
    exit()

open("docs/.nojekyll", "a").close()

# Directory with built shinylive assets
# This function will download and untar the assets if necessary, and then return
# the path to the assets directory.
SHINYLIVE_DIR = shiny._static._ensure_shinylive_local()

# It would be more convenient to copy these files using `resources` in
# _quarto.yml, but it doesn't seem to allow choosing the destination directory,
# so the files would end up on docs/prism-experiments/shinylive/ instead of
# docs/shinylive/.
shutil.copyfile(f"{SHINYLIVE_DIR}/serviceworker.js", "docs/serviceworker.js")
shutil.copytree(f"{SHINYLIVE_DIR}/shinylive", "docs/shinylive")
