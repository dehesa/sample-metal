import Cocoa

let (app, delegate) = (NSApplication.shared, App.Delegate())
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
