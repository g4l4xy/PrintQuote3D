// Run from repository root: swift tools/export-branding.swift
// Export supplied artwork into platform resource sizes; originals stay unchanged.
import AppKit
import ImageIO
import Foundation
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
func export(_ source: String, _ destination: String, _ size: Int, opaque: Bool = false) throws {
    let input = CGImageSourceCreateWithURL(root.appendingPathComponent(source) as CFURL, nil)!
    let image = CGImageSourceCreateImageAtIndex(input, 0, nil)!
    let context = CGContext(data:nil, width:size, height:size, bitsPerComponent:8, bytesPerRow:size*4, space:CGColorSpaceCreateDeviceRGB(), bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast).rawValue)!
    context.interpolationQuality = .high
    if opaque { context.setFillColor(CGColor(red:0.02,green:0.06,blue:0.12,alpha:1)); context.fill(CGRect(x:0,y:0,width:size,height:size)) }
    context.draw(image,in:CGRect(x:0,y:0,width:size,height:size))
    let url = root.appendingPathComponent(destination)
    try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
    let output = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(output,context.makeImage()!,nil)
    precondition(CGImageDestinationFinalize(output))
}
let icon="assets/branding/icon-dark.png"
for size in [16,32,64,128,256,512,1024] {
    try export(icon,"assets/branding/generated/icon-\(size).png",size)
}
try export(icon,"Sources/PrintQuoteApp/BrandAssets.xcassets/AppIcon.appiconset/ios-1024.png",1024,opaque:true)
for size in [16,32,128,256,512] { for scale in [1,2] {
    try export(icon,"Sources/PrintQuoteApp/BrandAssets.xcassets/AppIcon.appiconset/mac-\(size)@\(scale)x.png",size*scale)
}}
for (density,size) in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)] {
    try export(icon,"android/app/src/main/res/mipmap-\(density)/ic_launcher.png",size)
}
try export(icon,"Sources/PrintQuoteApp/BrandAssets.xcassets/BrandIcon.imageset/brand.png",256)
try export(icon,"Sources/PrintQuoteApp/Resources/BrandIcon.png",256)
let iconset=root.appendingPathComponent(".workflow/PrintQuote.iconset")
try FileManager.default.createDirectory(at:iconset,withIntermediateDirectories:true)
for size in [16,32,128,256,512] { for scale in [1,2] {
    let suffix=scale == 2 ? "@2x" : ""
    try export(icon,".workflow/PrintQuote.iconset/icon_\(size)x\(size)\(suffix).png",size*scale)
}}
let process=Process()
process.executableURL=URL(fileURLWithPath:"/usr/bin/iconutil")
process.arguments=["-c","icns",iconset.path,"-o",root.appendingPathComponent("assets/branding/PrintQuote.icns").path]
try process.run();process.waitUntilExit();precondition(process.terminationStatus==0)
