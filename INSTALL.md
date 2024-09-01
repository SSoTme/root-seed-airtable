# root-seed-airtable

This seed gets it's schema from the linked Airtable configured during the
first build.

It asks for an Airtable BaseId, and a few other project details.

Other seeds, unlawful project can be installed by running:

> ssotme -cloneseed https://github.com/your-account/seed-repo-xyz.git repo-xyz

This will clone the seed into that folder, and initiate:

`./new-seed-project/> ssotme -build`

## SSoT.me Settings

| Setting | Description |
|-|-|
| **`base-id`**|The Airtable BaseId that controls the schema for the project |
| <span style="white-space: nowrap">**`project-name`**</span>|This is the name of the project, that may be used as titles or headers throughout the project.|
