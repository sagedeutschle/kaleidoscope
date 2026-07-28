# Prismet Practice Casino Harness

This isolated launcher builds the production Practice Casino views without changing Prismet's active navigation or release targets.

Generate the project with `xcodegen generate`, then build the iOS scheme for both an iPhone and iPad simulator and the macOS scheme for the local Mac. The harness contains only app entry points; all table rules come from `PrismetShared`, and all presentation comes from the production platform Casino folders.
