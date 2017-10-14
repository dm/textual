/* ********************************************************************* 
                  _____         _               _
                 |_   _|____  _| |_ _   _  __ _| |
                   | |/ _ \ \/ / __| | | |/ _` | |
                   | |  __/>  <| |_| |_| | (_| | |
                   |_|\___/_/\_\\__|\__,_|\__,_|_|

 Copyright (c) 2010 - 2017 Codeux Software, LLC & respective contributors.
        Please see Acknowledgements.pdf for additional information.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Textual and/or "Codeux Software, LLC", nor the 
      names of its contributors may be used to endorse or promote products 
      derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

 *********************************************************************** */

NS_ASSUME_NONNULL_BEGIN

@interface ICMInlineImage ()
@property (nonatomic, strong, nullable) ICMInlineImageCheck *imageCheck;
@property (nonatomic, copy, readwrite) NSString *finalAddress;
@end

@implementation ICMInlineImage

- (void)_performAction
{
	/* Before the image is allowed to be displayed, we check that
	 it matches user preferences. These preferences include maximum
	 filesize and maximum height. */
	ICMInlineImageCheck *imageCheck = [ICMInlineImageCheck new];

	self.imageCheck = imageCheck;

	[imageCheck checkAddress:self.finalAddress
			 completionBlock:^(BOOL safeToLoad) {
			 if (safeToLoad) {
				 [self _safeToLoadImage];
			 } else {
				 [self _unsafeToLoadImage];
			 }

			 self.imageCheck = nil;
		 }];
}

- (void)_unsafeToLoadImage
{
	self.completionBlock(self.genericValidationFailedError);
}

- (void)_safeToLoadImage
{
	ICLPayloadMutable *payload = self.payload;

	NSDictionary *templateAttributes =
	@{
		@"anchorLink" : payload.url.absoluteString,
		@"imageURL" : self.finalAddress,
		@"preferredMaximumWidth" : @([TPCPreferences inlineImagesMaxWidth]),
		@"uniqueIdentifier" : payload.uniqueIdentifier
	};

	NSError *templateRenderError = nil;

	NSString *html = [self.template renderObject:templateAttributes error:&templateRenderError];

	/* We only want to assign to the payload if we have success (HTML) */
	if (html) {
		payload.html = html;

		payload.entrypoint = self.entrypoint;

		payload.scriptResources = self.scriptResources;
	}

	self.completionBlock(templateRenderError);
}

#pragma mark -
#pragma mark Action Block

+ (ICLInlineContentModuleActionBlock)actionBlockForFinalAddress:(NSString *)address
{
	NSParameterAssert(address != nil);

	return [^(ICLInlineContentModule *module) {
		__weak ICMInlineImage *moduleTyped = (id)module;

		moduleTyped.finalAddress = address;

		[moduleTyped _performAction];
	} copy];
}

#pragma mark -
#pragma mark Utilities

- (nullable GRMustacheTemplate *)template
{
	static GRMustacheTemplate *template = nil;
	
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		/* So you may wonder why the subfolder is named "Components" when these
		 are referred to as "Modules" — well it turns out Apple doesn't like the
		 latter. When that was used as a folder name, it would not appear in the
		 Resources folder of the service when copied to the main app. */
		NSString *templatePath =
		[RZMainBundle() pathForResource:@"ICMInlineImage" ofType:@"mustache" inDirectory:@"Components"];
		
		/* This module isn't designed to handle GRMustacheTemplate ever returning a
		 nil value, but if it ever happens, we log error to better understand why. */
		NSError *templateLoadError;
		
		template = [GRMustacheTemplate templateFromContentsOfFile:templatePath error:&templateLoadError];
		
		if (template == nil) {
			LogToConsoleError("Failed to load template '%@': %@",
				templatePath, templateLoadError.localizedDescription);
		}
	});
	
	return template;
}

- (nullable NSArray<NSString *> *)scriptResources
{
	static NSArray<NSString *> *scriptResources = nil;
	
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		scriptResources =
		@[
		  [RZMainBundle() pathForResource:@"InlineImageLiveResize" ofType:@"js"],
		  [RZMainBundle() pathForResource:@"ICMInlineImage" ofType:@"js" inDirectory:@"Components"]
		];
	});
	
	return scriptResources;
}

- (nullable NSString *)entrypoint
{
	return @"_ICMInlineImage.entrypoint";
}

+ (NSArray<NSString *> *)validImageContentTypes
{
	static NSArray<NSString *> *cachedValue = nil;
	
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		cachedValue =
		@[@"image/gif",
		  @"image/jpeg",
		  @"image/png",
		  @"image/svg+xml",
		  @"image/tiff",
		  @"image/x-ms-bmp"];
	});
	
	return cachedValue;
}

@end

NS_ASSUME_NONNULL_END
