//
//  ImageService.h
//  piwigo
//
//  Created by Spencer Baker on 1/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "NetworkHandler.h"

FOUNDATION_EXPORT NSString * const kGetImageOrderId;
FOUNDATION_EXPORT NSString * const kGetImageOrderFileName;
FOUNDATION_EXPORT NSString * const kGetImageOrderName;
FOUNDATION_EXPORT NSString * const kGetImageOrderVisits;
FOUNDATION_EXPORT NSString * const kGetImageOrderRating;
FOUNDATION_EXPORT NSString * const kGetImageOrderDateCreated;
FOUNDATION_EXPORT NSString * const kGetImageOrderDatePosted;
FOUNDATION_EXPORT NSString * const kGetImageOrderRandom;
FOUNDATION_EXPORT NSString * const kGetImageOrderAscending;
FOUNDATION_EXPORT NSString * const kGetImageOrderDescending;

@class PiwigoImageData;

@interface ImageService : NetworkHandler

+(NSURLSessionTask*)getImagesForAlbumId:(NSInteger)albumId
                                 onPage:(NSInteger)page
                               forOrder:(NSString*)order
                           OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *albumImages))completion
                              onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)getImagesForQuery:(NSString *)query
                               onPage:(NSInteger)page
                             forOrder:(NSString *)order
                         OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *searchedImages))completion
                            onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)getImagesForDiscoverId:(NSInteger)categoryId
                                    onPage:(NSInteger)page
                                  forOrder:(NSString *)order
                              OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *searchedImages))completion
                                 onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)getImagesForTagId:(NSInteger)tagId
                               onPage:(NSInteger)page
                             forOrder:(NSString *)order
                         OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *searchedImages))completion
                            onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)getFavoritesOnPage:(NSInteger)page
                              forOrder:(NSString *)order
                          OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *searchedImages))completion
                             onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)loadImageChunkForLastChunkCount:(NSInteger)lastImageBulkCount
                                        forCategory:(NSInteger)categoryId orQuery:(NSString*)query
                                             onPage:(NSInteger)onPage
                                            forSort:(NSString*)sort
                                   ListOnCompletion:(void (^)(NSURLSessionTask *task, NSInteger count))completion
                                          onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)getImageInfoById:(NSInteger)imageId
                        OnCompletion:(void (^)(NSURLSessionTask *task, PiwigoImageData *imageData))completion
                           onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLRequest*)urlRequestForImage:(PiwigoImageData*)image withMnimumSize:(CGFloat)minSize;
+(NSURL *)getFileUrlOfImage:(PiwigoImageData*)image withURLrequest:(NSURLRequest *)urlRequest;
+(NSURLSessionDownloadTask*)downloadImage:(PiwigoImageData*)imageData
                   withUrlRequest:(NSURLRequest*)urlRequest
                       onProgress:(void (^)(NSProgress *))progress
                completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler;

+(NSURLSessionDownloadTask*)downloadVideo:(PiwigoImageData*)video
                   withUrlRequest:(NSURLRequest*)urlRequest
                       onProgress:(void (^)(NSProgress *))progress
                completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler;

+(NSURLSessionTask*)deleteImage:(PiwigoImageData*)image
               ListOnCompletion:(void (^)(NSURLSessionTask *task))completion
                      onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)deleteImages:(NSArray *)images
                ListOnCompletion:(void (^)(NSURLSessionTask *task))completion
                       onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)setImageProperties:(PiwigoImageData *)imageData
                            onProgress:(void (^)(NSProgress *))progress
                          OnCompletion:(void (^)(NSURLSessionTask *task, id response))completion
                             onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)setImageInfoForImageWithId:(NSInteger)imageId
                                   information:(NSDictionary*)imageInformation
                                sessionManager:(AFHTTPSessionManager *)sessionManager
                                    onProgress:(void (^)(NSProgress *))progress
                                  OnCompletion:(void (^)(NSURLSessionTask *task, id response))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)setImageFileForImageWithId:(NSInteger)imageId
                                  withFileName:(NSString*)fileName
                                    onProgress:(void (^)(NSProgress *))progress
                                  OnCompletion:(void (^)(NSURLSessionTask *task, id response))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)setCategoriesForImage:(PiwigoImageData *)imageId
                           withCategories:(NSArray *)imageCategories
                               onProgress:(void (^)(NSProgress *))progress
                             OnCompletion:(void (^)(NSURLSessionTask *task, BOOL setCategoriesSuccessfully))completion
                                onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)addImageToFavorites:(PiwigoImageData *)image
                             onProgress:(void (^)(NSProgress *))progress
                           OnCompletion:(void (^)(NSURLSessionTask *task, BOOL addedSuccessfully))completion
                              onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)removeImageFromFavorites:(PiwigoImageData *)image
                                  onProgress:(void (^)(NSProgress *))progress
                                OnCompletion:(void (^)(NSURLSessionTask *task, BOOL removedSuccessfully))completion
                                   onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSMutableDictionary *)stripGPSdataFromImageMetadata:(NSDictionary *)metadata;
+(NSMutableDictionary *)fixMetadata:(NSDictionary *)originalMetadata ofImage:(UIImage*)image;
+(NSData*)writeMetadata:(NSDictionary*)metadata intoImageData:(NSData *)imageData;

@end
