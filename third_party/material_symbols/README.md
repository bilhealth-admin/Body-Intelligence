# Material Symbols (Android semantic icons)

The 54 `android/app/src/main/res/drawable/bil_symbol_*.xml` files are official
Google Material Symbols Rounded VectorDrawables (24 px).

Source: https://github.com/google/material-design-icons/tree/0cbb08816df07faaae3dca060d4ebb10b66c214f/symbols/android

Pinned upstream revision: `0cbb08816df07faaae3dca060d4ebb10b66c214f`.
License: Apache 2.0; see [LICENSE](LICENSE).

The Android bridge renders these bundled vectors locally. The iOS bridge uses
UIKit `UIImage(systemName:)` and does not bundle or redistribute Apple's symbols.
The shared semantic-icon layer uses this bridge across app features, with
dedicated Settings/Profile styling. Desktop/web fallback icons are previews
and are not evidence of native iOS rendering.
