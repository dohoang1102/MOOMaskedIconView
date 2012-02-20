//
//  GOODMaskedIconView.m
//
//  Created by Peyton Randolph on 2/6/12.
//

#import "GOODMaskedIconView.h"

#import <QuartzCore/QuartzCore.h>

static NSString * const GOODMaskedIconViewHighlightedKey = @"highlighted";
static NSString * const GOODMaskedIconViewMaskKey = @"mask";

@interface GOODMaskedIconView ()

@property (nonatomic, assign) CGImageRef mask;

- (UIImage *)_renderImageHighlighted:(BOOL)shouldBeHighlighted;
+ (NSURL *)_resourceURL:(NSString *)resourceName;

@end

@implementation GOODMaskedIconView
@synthesize highlighted = _highlighted;

@synthesize color = _color;
@synthesize highlightedColor = _highlightedColor;

@synthesize drawingBlock = _drawingBlock;
@synthesize mask = _mask;

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame]))
        return nil;
    
    // Set view defaults
    self.backgroundColor = [UIColor clearColor];
    self.color = [UIColor blackColor];
    
    // Set up observing
    [self addObserver:self forKeyPath:GOODMaskedIconViewHighlightedKey options:0 context:NULL];
    [self addObserver:self forKeyPath:GOODMaskedIconViewMaskKey options:0 context:NULL];
    
    return self;
}

- (id)initWithImage:(UIImage *)image;
{
    return [self initWithImage:image size:CGSizeZero];
}

- (id)initWithImage:(UIImage *)image size:(CGSize)size;
{
    if (!(self = [self initWithFrame:CGRectZero]))
        return nil;
    
    // Configure with image
    [self configureWithImage:image size:size];

    return self;
}

- (id)initWithImageNamed:(NSString *)imageName;
{
    return [self initWithImageNamed:imageName size:CGSizeZero];
}

- (id)initWithImageNamed:(NSString *)imageName size:(CGSize)size;
{
    if (!(self = [self initWithFrame:CGRectZero]))
        return nil;
    
    [self configureWithImageNamed:imageName size:size];
    
    return self;
}

- (id)initWithPDFNamed:(NSString *)pdfName;
{
    return [self initWithPDFNamed:pdfName size:CGSizeZero];
}

- (id)initWithPDFNamed:(NSString *)pdfName size:(CGSize)size;
{
    if (!(self = [self initWithFrame:CGRectZero]))
        return nil;
    
    [self configureWithPDFNamed:pdfName size:size];
    
    return self;
}

- (id)initWithResourceNamed:(NSString *)resourceName;
{
    return [self initWithResourceNamed:resourceName size:CGSizeZero];
}

- (id)initWithResourceNamed:(NSString *)resourceName size:(CGSize)size;
{
    if (!(self = [self initWithFrame:CGRectZero]))
        return nil;
    
    [self configureWithResourceNamed:resourceName size:size];
    
    return self;
}

- (void)dealloc;
{
    [self removeObserver:self forKeyPath:GOODMaskedIconViewHighlightedKey];
    [self removeObserver:self forKeyPath:GOODMaskedIconViewMaskKey];

    self.color = nil;
    self.drawingBlock = NULL;
    self.highlightedColor = nil;
    self.mask = NULL;
}

#pragma mark - Drawing and layout methods

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Flip coordinates so images don't draw upside down
    CGContextTranslateCTM(context, 0.0f, CGRectGetHeight(rect));
    CGContextScaleCTM(context, 1.0f, -1.0f);
    
    // Clip drawing to icon image
    CGContextClipToMask(context, rect, self.mask);
    
    // Fill icon with color
    CGContextSaveGState(context);
    if (self.highlighted && self.highlightedColor)
        [self.highlightedColor set];
    else
        [self.color set];
    CGContextFillRect(context, rect);
    CGContextRestoreGState(context);
    
    // Perform additional drawing if specified
    if (self.drawingBlock != NULL)
    {
        CGContextSaveGState(context);
        self.drawingBlock(context);
        CGContextRestoreGState(context);
    }
}

- (CGSize)sizeThatFits:(CGSize)size;
{
    CGFloat scale = [UIScreen mainScreen].scale;
    return CGSizeMake(CGImageGetWidth(self.mask) / scale, CGImageGetHeight(self.mask) / scale);
}

#pragma mark - Getters and setters

- (void)setMask:(CGImageRef)mask;
{
    if (mask == self.mask)
        return;
    
    CGImageRelease(_mask);
    _mask = CGImageRetain(mask);
    
    // Resize view when mask changes
    [self sizeToFit];
    [self setNeedsDisplay];
}

#pragma mark - Configuration methods

- (void)configureWithImage:(UIImage *)image;
{
    [self configureWithImage:image size:CGSizeZero];
}

- (void)configureWithImage:(UIImage *)image size:(CGSize)size;
{
    if (image == nil)
    {
        self.mask = NULL;
        return;
    }
    
    CGImageRef imageRef = image.CGImage;
    CGSize imageSize = CGSizeZero;
    size_t bytesPerRow = 0;
    
    if (size.width > 0.0f && size.height > 0.0f) 
    {
        imageSize = size;
        bytesPerRow = CGImageGetWidth(imageRef) * CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(imageRef));
    }
    else 
    {
        imageSize = CGSizeMake(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef));
        bytesPerRow = CGImageGetBytesPerRow(imageRef);
    }
    
    CGImageRef maskRef = CGImageMaskCreate(imageSize.width, imageSize.height, CGImageGetBitsPerComponent(imageRef), CGImageGetBitsPerPixel(imageRef), bytesPerRow, CGImageGetDataProvider(imageRef), NULL, NO);
    self.mask = maskRef;
    CGImageRelease(maskRef);
}

- (void)configureWithImageNamed:(NSString *)imageName;
{
    return [self configureWithImageNamed:imageName size:CGSizeZero];
}

- (void)configureWithImageNamed:(NSString *)imageName size:(CGSize)size;
{
    NSURL *imageURL = [GOODMaskedIconView _resourceURL:imageName];
    UIImage *image = [UIImage imageWithContentsOfFile:[imageURL relativePath]];

    [self configureWithImage:image size:size];
}

- (void)configureWithPDFNamed:(NSString *)pdfName;
{
    [self configureWithPDFNamed:pdfName size:CGSizeZero];
}

- (void)configureWithPDFNamed:(NSString *)pdfName size:(CGSize)size;
{
    if (!pdfName)
        return;
    
    // Grab pdf
    NSURL *pdfURL = [GOODMaskedIconView _resourceURL:pdfName];
    CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((__bridge CFURLRef)pdfURL);
    CGPDFPageRef firstPage = CGPDFDocumentGetPage(pdf, 1);
    
    if (firstPage == NULL)
    {
        CGPDFDocumentRelease(pdf);
        return;
    }
    
    // Calculate metrics
    CGRect mediaRect = CGPDFPageGetBoxRect(firstPage, kCGPDFCropBox);
    CGSize pdfSize = (size.width > 0.0f && size.height > 0.0f) ? size : mediaRect.size;
    
    // Set up context
    UIGraphicsBeginImageContextWithOptions(pdfSize, YES, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Draw background
    [[UIColor whiteColor] set];
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, pdfSize.width, pdfSize.height));
    
    // Scale and flip context right-side-up
    CGContextScaleCTM(context, pdfSize.width / mediaRect.size.width, -pdfSize.height / mediaRect.size.height);
    CGContextTranslateCTM(context, 0.0f, -mediaRect.size.height);
    
    // Draw pdf
    CGContextDrawPDFPage(context, firstPage);
    CGPDFDocumentRelease(pdf);

    // Create image to mask
    CGImageRef imageToMask = CGBitmapContextCreateImage(context);
    UIGraphicsEndImageContext();
    
    // Create image mask
    CGImageRef maskRef = CGImageMaskCreate(CGImageGetWidth(imageToMask), CGImageGetHeight(imageToMask), CGImageGetBitsPerComponent(imageToMask), CGImageGetBitsPerPixel(imageToMask), CGImageGetBytesPerRow(imageToMask), CGImageGetDataProvider(imageToMask), NULL, NO);
    CGImageRelease(imageToMask);
    self.mask = maskRef;
    CGImageRelease(maskRef);
}

- (void)configureWithResourceNamed:(NSString *)resourceName;
{
    [self configureWithResourceNamed:resourceName size:CGSizeZero];
}

- (void)configureWithResourceNamed:(NSString *)resourceName size:(CGSize)size;
{
    NSString *extension = [resourceName pathExtension];
    if ([extension isEqualToString:@"pdf"])
        [self configureWithPDFNamed:resourceName size:size];
    else 
        [self configureWithImageNamed:resourceName size:size];
}

#pragma mark - KVO methods

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
    if ([keyPath isEqualToString:GOODMaskedIconViewHighlightedKey])
        [self setNeedsDisplay];
}

#pragma mark - Image rendering

- (UIImage *)renderImage;
{
    return [self _renderImageHighlighted:NO];
}

- (UIImage *)renderHighlightedImage;
{
    return [self _renderImageHighlighted:YES];
}

#pragma mark - FOR PRIVATE EYES ONLY

- (UIImage *)_renderImageHighlighted:(BOOL)shouldBeHighlighted;
{
    // Save state
    BOOL wasHighlighted = self.isHighlighted;
    
    // Render image
    self.highlighted = shouldBeHighlighted;
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0.0f);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Restore state
    self.highlighted = wasHighlighted;
    
    return image;
}

+ (NSURL *)_resourceURL:(NSString *)resourceName
{
    if (!resourceName)
        return nil;
    
    NSString *path = [[NSBundle mainBundle] pathForResource:resourceName ofType:nil];
    if (!path)
    {
        NSLog(@"File named %@ not found by %@. Check capitalization?", resourceName, self);
        return nil;
    }
    
    return [NSURL fileURLWithPath:path];
}

@end
