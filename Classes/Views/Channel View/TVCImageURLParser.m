/* ********************************************************************* 
       _____        _               _    ___ ____   ____
      |_   _|___  _| |_ _   _  __ _| |  |_ _|  _ \ / ___|
       | |/ _ \ \/ / __| | | |/ _` | |   | || |_) | |
       | |  __/>  <| |_| |_| | (_| | |   | ||  _ <| |___
       |_|\___/_/\_\\__|\__,_|\__,_|_|  |___|_| \_\\____|

 Copyright (c) 2010 — 2013 Codeux Software & respective contributors.
        Please see Contributors.rtfd and Acknowledgements.rtfd

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Textual IRC Client & Codeux Software nor the
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

#import "TextualApplication.h"

@implementation TVCImageURLParser

+ (NSArray *)validImageContentTypes
{
	/* List based off https://en.wikipedia.org/wiki/Internet_media_type#Type_image */

	return @[@"image/gif", @"image/jpeg", @"image/png", @"image/svg+xml"];
}

+ (NSString *)imageURLFromBase:(NSString *)url
{
	NSString *lowerUrl = [url lowercaseString];

	NSURL *u = [NSURL URLWithString:[url encodeURIFragment]];

	NSString *scheme = u.scheme;
	
	NSString *host = [u.host lowercaseString];
	NSString *path = [u.path encodeURIFragment];

	if ([scheme isEqualToString:@"file"]) {
		// If the file is a local file (file:// scheme), then let us ignore it.
		// Because Textual is in a sandbox, we will not have permission to linked
		// local files unless they are stored relative to our container.
		//
		// For example, the user may post the URL "file:///Users/Michael/Desktop/mom.jpg"
		// because they have a file named mom.jpg on their Desktop. Textual does not have
		// access to the actual users Desktop unless the user explicitly tells us that we
		// do. Therefore, this image would create an error trying to display it.
		//
		// Our sandbox path is returned using NSHomeDirectory() so we can at least
		// check for that within the link and pass it along if it is there. Even doing
		// this is unsafe to an extent and normally pointless.
		//
		// Who would push something to our sandbox to just link for themselves? No one
		// on IRC would actually be able to see the linked image. 

		if ([lowerUrl containsIgnoringCase:NSHomeDirectory()] == NO) {
			return nil;
		}
	}

	NSString *plguinResult = [RZPluginManager() processInlineMediaContentURL:url];

	if (NSObjectIsNotEmpty(plguinResult)) {
		return plguinResult;
	}

	// The following parsing engine is mostly unmainted by Codeux Software. Nearly all, if
	// not all, is left over legacy code from Limechat when we forked it. There are one or
	// two exceptions from push requests, but it is mostly unchanged.
	//
	// It is encouraged that developers with the knowledge contribute to this class as
	// it is not of high priority. Only when a user requests an addition will any be done.
	// Beyond that, it is only updated to match changes to the underlying codebase. 

	BOOL hadExtension = NO;

	if ([lowerUrl hasSuffix:@".jpg"] ||
		[lowerUrl hasSuffix:@".jpeg"] ||
		[lowerUrl hasSuffix:@".png"] ||
		[lowerUrl hasSuffix:@".gif"] ||
		[lowerUrl hasSuffix:@".tif"] ||
		[lowerUrl hasSuffix:@".tiff"] ||
		[lowerUrl hasSuffix:@".bmp"])
	{
		hadExtension = YES;

        if ([host hasSuffix:@"wikipedia.org"]) {
            return nil;
        } else if ([url hasPrefix:@"http://fukung.net/v/"]) {
			return [url stringByReplacingOccurrencesOfString:@"http://fukung.net/v/" withString:@"http://media.fukung.net/images/"];
        } else if ([host hasSuffix:@"dropbox.com"]) {
			// Continue to processing…
		} else {
			return url;
		}
	}

	if ([host hasSuffix:@"dropbox.com"]) {
		if ([path hasPrefix:@"/s/"] && hadExtension) {
			return [@"https://dl.dropboxusercontent.com" stringByAppendingString:path];
		}
	} else if ([host hasSuffix:@"instacod.es"]) {
		NSObjectIsEmptyAssertReturn(path, nil);

		NSString *s = [path safeSubstringFromIndex:1];

		if ([s isNumericOnly]) {
			return [@"http://instacod.es/file/" stringByAppendingString:s];
		}
	} else if ([host hasPrefix:@"docs.google.com"]) {
		if ([path hasPrefix:@"/file/d/"]) {
			NSArray *parts = [path componentsSeparatedByString:@"/"];

			NSAssertReturnR((parts.count == 4 || parts.count == 5), nil);

			NSString *photoID;

			if (parts.count == 5) {
				if ([parts[4] isEqualToString:@"edit"]) { // Add a little validation.
					photoID = parts[3];
				}
			} else {
				photoID = parts[3];
			}

			if (photoID) {
				return [@"https://docs.google.com/uc?id=" stringByAppendingString:photoID];
			}
		}
	} else if ([host hasSuffix:@"twitpic.com"]) {
		NSObjectIsEmptyAssertReturn(path, nil);

		NSString *s = [path safeSubstringFromIndex:1];

		if ([s hasSuffix:@"/full"]) {
			s = [s safeSubstringToIndex:(s.length - 5)];
		}

		if ([s isAlphabeticNumericOnly]) {
			return [NSString stringWithFormat:@"http://twitpic.com/show/large/%@", s];
		}
	} else if ([host hasSuffix:@"cl.ly"]) {
		NSObjectIsEmptyAssertReturn(path, nil);

		NSString *p = [path safeSubstringFromIndex:1];
        
        NSArray *components = [p componentsSeparatedByString:@"/"];

		NSAssertReturnR((components.count == 2), nil);

		NSString *p1 = components[0];
		NSString *p2 = components[1];

        if ([p1 isEqualIgnoringCase:@"image"]) {
            return [NSString stringWithFormat:@"http://cl.ly/%@/content", p2];
        }
	} else if ([host hasSuffix:@"tweetphoto.com"]) {
		NSObjectIsEmptyAssertReturn(path, nil);

		return [NSString stringWithFormat:@"http://TweetPhotoAPI.com/api/TPAPI.svc/imagefromurl?size=medium&url=%@", [url encodeURIComponent]];
	} else if ([host hasSuffix:@"yfrog.com"]) {
		NSObjectIsEmptyAssertReturn(path, nil);

		return [NSString stringWithFormat:@"%@:iphone", url];
	} else if ([host hasSuffix:@"twitgoo.com"]) {
		NSObjectIsEmptyAssertReturn(path, nil);

		NSString *s = [path safeSubstringFromIndex:1];

		if ([s isAlphabeticNumericOnly]) {
			return [NSString stringWithFormat:@"http://twitgoo.com/show/Img/%@", s];
		}
	} else if ([host isEqualToString:@"img.ly"]) {
		NSObjectIsEmptyAssertReturn(path, nil);

		NSString *s = [path safeSubstringFromIndex:1];

		if ([s isAlphabeticNumericOnly]) {
			return [NSString stringWithFormat:@"http://img.ly/show/large/%@", s];
		}
	} else if ([host hasSuffix:@"movapic.com"]) {
		if ([path hasPrefix:@"/pic/"]) {
			NSString *s = [path safeSubstringFromIndex:5];

			if ([s isAlphabeticNumericOnly]) {
				return [NSString stringWithFormat:@"http://image.movapic.com/pic/m_%@.jpeg", s];
			}
		}
	} else if ([host hasSuffix:@"f.hatena.ne.jp"]) {
		NSArray *ary = [path componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];

		if (ary.count >= 3) {
			NSString *userId = [ary safeObjectAtIndex:1];
			NSString *photoId = [ary safeObjectAtIndex:2];

			if (userId.length && photoId.length > 8 && [photoId isNumericOnly]) {
				NSString *userIdHead  = [userId safeSubstringToIndex:1];
				NSString *photoIdHead = [photoId safeSubstringToIndex:8];

				return [NSString stringWithFormat:@"http://img.f.hatena.ne.jp/images/fotolife/%@/%@/%@/%@.jpg", userIdHead, userId, photoIdHead, photoId];
			}
		}
	} else if ([host isEqualToString:@"puu.sh"]) {
		NSObjectIsEmptyAssertReturn(path, nil);

		NSString *s = [path safeSubstringFromIndex:1];

		if ([s isAlphabeticNumericOnly]) {
			return [NSString stringWithFormat:@"http://puu.sh/%@.jpg", s];
		}
	/* } else if ([host hasSuffix:@"imgur.com"]) {
		if ([path hasPrefix:@"/gallery/"]) {
			NSString *s = [path safeSubstringFromIndex:9];

			if ([s isAlphabeticNumericOnly]) {
				return [NSString stringWithFormat:@"http://i.imgur.com/%@.png", s];
			}
		} */
	} else if ([host hasSuffix:@"d.pr"]) {
		if ([path hasPrefix:@"/i/"]) {
			NSString *s = [path safeSubstringFromIndex:3];

			if ([s isAlphabeticNumericOnly]) {
				return [NSString stringWithFormat:@"http://d.pr/i/%@.png", s];
			}
		}
	} else if ([host hasSuffix:@"youtube.com"] || [host isEqualToString:@"youtu.be"]) {
		NSString *vid = nil;

		if ([host isEqualToString:@"youtu.be"]) {
			NSString *path = u.path;

			if (NSObjectIsNotEmpty(path)) {
				vid = [path safeSubstringFromIndex:1];
			}
		} else {
			NSString *query = u.query;

			if (query.length) {
				NSArray *queries = [query componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"&"]];

				if (NSObjectIsNotEmpty(queries)) {
					NSCharacterSet *equal = [NSCharacterSet characterSetWithCharactersInString:@"="];

					for (NSString *e in queries) {
						NSArray *ary = [e componentsSeparatedByCharactersInSet:equal];

						if (ary.count >= 2) {
							NSString *key = [ary safeObjectAtIndex:0];
							NSString *value = [ary safeObjectAtIndex:1];

							if ([key isEqualToString:@"v"]) {
								vid = value;

								break;
							}
						}
					}
				}
			}
		}

		if (vid) {
			if (vid.length > 11) {
				/* This behavior is was found by accident but is quite interesting. YouTube
				 links limit the video ID to a maximum length of eleven. If it exceeds that,
				 it only takes the first eleven characters. So a video link like:
				 
				 http://www.youtube.com/watch?v=qMkYlIA7mgw7435345354354343
				 
				 will actually be seen as:
				 
				 http://www.youtube.com/watch?v=qMkYlIA7mgw
				 
				 This is all fine and cool, but their image server does not do the same.
				 Therefore, this is a fix in Textual to catch the length and resize so that
				 we provide valid images for the weird links. */

				vid = [vid safeSubstringToIndex:11];
			}

			return [NSString stringWithFormat:@"http://i.ytimg.com/vi/%@/mqdefault.jpg", vid];
		}
	} else if ([host hasSuffix:@"nicovideo.jp"] || [host isEqualToString:@"nico.ms"]) {
		NSString *vid = nil;

		if ([host isEqualToString:@"nico.ms"]) {
			NSString *path = u.path;

			if (NSObjectIsNotEmpty(path)) {
				path = [path safeSubstringFromIndex:1];

				if ([path hasPrefix:@"sm"] || [path hasPrefix:@"nm"]) {
					vid = path;
				}
			}
		} else {
			NSString *path = u.path;

			if ([path hasPrefix:@"/watch/"]) {
				path = [path safeSubstringFromIndex:7];

				if ([path hasPrefix:@"sm"] || [path hasPrefix:@"nm"]) {
					vid = path;
				}
			}
		}

		if (vid && vid.length > 2) {
			long long vidNum = [[vid safeSubstringFromIndex:2] longLongValue];

			return [NSString stringWithFormat:@"http://tn-skr%qi.smilevideo.jp/smile?i=%qi", ((vidNum % 4) + 1), vidNum];
		}
	} else if ([path hasPrefix:@"/image/"]) {
		/* Try our best to regonize cl.ly custom domains. */

		NSString *s = [path safeSubstringFromIndex:7];

		if ([s isAlphabeticNumericOnly] && s.length == 12) {
			return [NSString stringWithFormat:@"http://cl.ly%@/content", path];
		}
	}

	return nil;
}

@end
