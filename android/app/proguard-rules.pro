# R8/ProGuard rules for the release build.
#
# Suppress "Missing class" warnings for optional classes that are referenced by
# transitive libraries but are not present on the compile classpath (foldable
# window extensions/sidecar, and Compose UI test hooks). R8 escalates these to
# build failures unless explicitly suppressed. Generated from R8's
# missing_rules.txt — safe: these are optional APIs, not code we ship.
-dontwarn androidx.compose.ui.geometry.Rect
-dontwarn androidx.compose.ui.node.RootForTest
-dontwarn androidx.compose.ui.semantics.SemanticsConfiguration
-dontwarn androidx.compose.ui.semantics.SemanticsNode
-dontwarn androidx.compose.ui.semantics.SemanticsOwner
-dontwarn androidx.compose.ui.semantics.SemanticsOwnerKt
-dontwarn androidx.compose.ui.semantics.SemanticsProperties
-dontwarn androidx.compose.ui.semantics.SemanticsPropertyKey
-dontwarn androidx.window.extensions.WindowExtensions
-dontwarn androidx.window.extensions.WindowExtensionsProvider
-dontwarn androidx.window.extensions.area.ExtensionWindowAreaPresentation
-dontwarn androidx.window.extensions.layout.DisplayFeature
-dontwarn androidx.window.extensions.layout.FoldingFeature
-dontwarn androidx.window.extensions.layout.WindowLayoutComponent
-dontwarn androidx.window.extensions.layout.WindowLayoutInfo
-dontwarn androidx.window.sidecar.SidecarDeviceState
-dontwarn androidx.window.sidecar.SidecarDisplayFeature
-dontwarn androidx.window.sidecar.SidecarInterface$SidecarCallback
-dontwarn androidx.window.sidecar.SidecarInterface
-dontwarn androidx.window.sidecar.SidecarProvider
-dontwarn androidx.window.sidecar.SidecarWindowLayoutInfo
