// Run from repository root: swift tools/export-branding.swift
// One vector geometry source; deterministic platform exports. Originals remain archived.
import AppKit
import ImageIO
import Foundation
struct Shape: Decodable { let color: String; let points: [[Double]] }
struct Geometry: Decodable { let paths: [Shape] }
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let geometry=try JSONDecoder().decode(Geometry.self,from:Data(contentsOf:root.appendingPathComponent("assets/branding/geometry.json")))
let navy="#07182E"
func palette(_ dark:Bool)->[String:String] { ["navy":dark ? "#C5E1F7":"#0A2544","blue":"#0873FF","cyan":"#00CBE6","white":dark ? "#FFFFFF":"#DFEFFF"] }
func color(_ hex:String)->CGColor {
    let n=UInt32(hex.dropFirst(),radix:16)!
    return CGColor(red:CGFloat((n>>16)&255)/255,green:CGFloat((n>>8)&255)/255,blue:CGFloat(n&255)/255,alpha:1)
}
func save(_ image:CGImage,_ path:String) throws {
    let url=root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
    let out=CGImageDestinationCreateWithURL(url as CFURL,"public.png" as CFString,1,nil)!
    CGImageDestinationAddImage(out,image,nil);precondition(CGImageDestinationFinalize(out))
}
func mark(_ context:CGContext,_ rect:CGRect,_ dark:Bool) {
    context.saveGState();context.translateBy(x:rect.minX,y:rect.minY);context.scaleBy(x:rect.width/256,y:rect.height/256)
    for shape in geometry.paths {
        let p=CGMutablePath();p.move(to:CGPoint(x:shape.points[0][0],y:shape.points[0][1]))
        for v in shape.points.dropFirst(){p.addLine(to:CGPoint(x:v[0],y:v[1]))};p.closeSubpath()
        context.setFillColor(color(palette(dark)[shape.color]!));context.addPath(p);context.fillPath()
    };context.restoreGState()
}
func export(_ path:String,_ size:Int,_ style:String) throws {
    let opaque=style=="ios"
    let c=CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:size*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:(opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast).rawValue)!
    c.translateBy(x:0,y:CGFloat(size));c.scaleBy(x:1,y:-1)
    let full=CGRect(x:0,y:0,width:size,height:size)
    if style=="ios" {c.setFillColor(color(navy));c.fill(full)}
    if style=="mac" || style=="legacy" {
        let inset=CGFloat(size)*0.08
        c.setFillColor(color(navy));c.addPath(CGPath(roundedRect:full.insetBy(dx:inset,dy:inset),cornerWidth:CGFloat(size)*0.18,cornerHeight:CGFloat(size)*0.18,transform:nil));c.fillPath()
    }
    // Adaptive foreground fits entirely in the central safe area, including circular masks.
    let fraction:CGFloat=style=="adaptive" ? 0.66 : (style=="mark" || style=="light" ? 1 : 0.86)
    let side=CGFloat(size)*fraction
    mark(c,CGRect(x:(CGFloat(size)-side)/2,y:(CGFloat(size)-side)/2,width:side,height:side),style != "light")
    try save(c.makeImage()!,path)
}
func svgMark(_ dark:Bool)->String {
    geometry.paths.map { s in
        let points=s.points.map {"\($0[0]),\($0[1])"}.joined(separator:" ")
        return "<polygon fill=\"\(palette(dark)[s.color]!)\" points=\"\(points)\"/>"
    }.joined()
}
for dark in [false,true] {
    let suffix=dark ? "dark":"light", ink=dark ? "#F0F6FC":"#0A2544", secondary=dark ? "#AFC5DB":"#49637E"
    let svg="""
    <svg xmlns="http://www.w3.org/2000/svg" width="1040" height="240" viewBox="0 0 1040 240" role="img" aria-label="PrintQuote — Real parts. Real prices. Faster.">
    <g transform="translate(20 12) scale(.82)">\(svgMark(dark))</g>
    <text x="250" y="132" font-family="Arial, Helvetica, sans-serif" font-size="100" font-weight="700" letter-spacing="-4" fill="\(ink)">Print<tspan fill="#0873FF">Quote</tspan></text>
    <text x="254" y="178" font-family="Arial, Helvetica, sans-serif" font-size="22" font-weight="500" letter-spacing="3" fill="\(secondary)">REAL PARTS. REAL PRICES. FASTER.</text>
    </svg>
    """
    try svg.write(to:root.appendingPathComponent("assets/branding/generated/wordmark-\(suffix).svg"),atomically:true,encoding:.utf8)
    try export("assets/branding/generated/mark-\(suffix).png",256,dark ? "mark":"light")
}
for size in [16,32,64,128,256,512,1024] {try export("assets/branding/generated/icon-\(size).png",size,"mac")}
try export("Sources/PrintQuoteApp/BrandAssets.xcassets/AppIcon.appiconset/ios-1024.png",1024,"ios")
for size in [16,32,128,256,512] {for scale in [1,2] {try export("Sources/PrintQuoteApp/BrandAssets.xcassets/AppIcon.appiconset/mac-\(size)@\(scale)x.png",size*scale,"mac")}}
for (density,size) in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)] {try export("android/app/src/main/res/mipmap-\(density)/ic_launcher.png",size,"legacy")}
try export("android/app/src/main/res/drawable-nodpi/brand_mark.png",256,"mark")
try export("android/app/src/main/res/drawable-nodpi/launcher_foreground.png",432,"adaptive")
try export("Sources/PrintQuoteApp/BrandAssets.xcassets/BrandIcon.imageset/brand.png",256,"mark")
try export("Sources/PrintQuoteApp/Resources/BrandIcon.png",256,"mark")
let iconset=root.appendingPathComponent(".workflow/PrintQuote.iconset")
try FileManager.default.createDirectory(at:iconset,withIntermediateDirectories:true)
for size in [16,32,128,256,512] {for scale in [1,2] {try export(".workflow/PrintQuote.iconset/icon_\(size)x\(size)\(scale==2 ? "@2x":"").png",size*scale,"mac")}}
let process=Process();process.executableURL=URL(fileURLWithPath:"/usr/bin/iconutil");process.arguments=["-c","icns",iconset.path,"-o",root.appendingPathComponent("assets/branding/PrintQuote.icns").path];try process.run();process.waitUntilExit();precondition(process.terminationStatus==0)
