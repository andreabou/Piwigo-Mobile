//
//  UploadViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

#import "AppDelegate.h"
#import "CategoriesData.h"
#import "ImageDetailViewController.h"
#import "ImageUpload.h"
#import "ImageUploadManager.h"
#import "ImageUploadProgressView.h"
#import "ImageUploadViewController.h"
#import "ImagesCollection.h"
#import "ImagesHeaderReusableView.h"
#import "LoadingView.h"
#import "LocalImageCollectionViewCell.h"
#import "NoImagesHeaderCollectionReusableView.h"
#import "PhotosFetch.h"
#import "SortLocalImages.h"
#import "UICountingLabel.h"
#import "UploadViewController.h"

@interface UploadViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, PHPhotoLibraryChangeObserver, ImageUploadProgressDelegate, ImagesHeaderDelegate>

@property (nonatomic, strong) UICollectionView *localImagesCollection;
@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, assign) NSInteger nberOfImagesPerRow;
@property (nonatomic, strong) NSArray *images;
@property (nonatomic, strong) NSMutableArray *imagesInSections;
@property (nonatomic, strong) PHAssetCollection *groupAsset;

@property (nonatomic, strong) UILabel *noImagesLabel;

@property (nonatomic, strong) UIBarButtonItem *sortBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *uploadBarButton;

@property (nonatomic, strong) NSMutableArray *selectedImages;
@property (nonatomic, strong) NSMutableArray *selectedSections;
@property (nonatomic, strong) NSMutableArray *touchedImages;

@property (nonatomic, assign) kPiwigoSortBy sortType;
@property (nonatomic, strong) LoadingView *loadingView;

@end

@implementation UploadViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId andGroupAsset:(PHAssetCollection*)groupAsset
{
    self = [super init];
    if(self)
    {
        self.view.backgroundColor = [UIColor piwigoBackgroundColor];
        self.categoryId = categoryId;
        self.groupAsset = groupAsset;
        self.images = [[PhotosFetch sharedInstance] getImagesForAssetGroup:self.groupAsset];
        self.sortType = kPiwigoSortByNewest;
        [self splitImages];
        
        // Collection of images
        self.localImagesCollection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[UICollectionViewFlowLayout new]];
        self.localImagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
        self.localImagesCollection.backgroundColor = [UIColor clearColor];
        self.localImagesCollection.alwaysBounceVertical = YES;
        self.localImagesCollection.showsVerticalScrollIndicator = YES;
        self.localImagesCollection.dataSource = self;
        self.localImagesCollection.delegate = self;

        [self.localImagesCollection registerClass:[LocalImageCollectionViewCell class] forCellWithReuseIdentifier:@"LocalImageCollectionViewCell"];
        [self.localImagesCollection registerClass:[NoImagesHeaderCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"NoImagesHeaderCollection"];
        [self.localImagesCollection registerNib:[UINib nibWithNibName:@"ImagesHeaderReusableView" bundle:nil] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"ImagesHeaderReusableView"];

        [self.view addSubview:self.localImagesCollection];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.localImagesCollection]];
        if (@available(iOS 11.0, *)) {
            [self.localImagesCollection setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentAlways];
        } else {
            // Fallback on earlier versions
        }

        // Selected images
        self.selectedImages = [NSMutableArray new];
        self.touchedImages = [NSMutableArray new];
        
        // Bar buttons
        self.sortBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"list"] landscapeImagePhone:[UIImage imageNamed:@"listCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(askSortType)];
        [self.sortBarButton setAccessibilityIdentifier:@"Sort"];
        self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
        [self.cancelBarButton setAccessibilityIdentifier:@"Cancel"];
        self.uploadBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"upload"] style:UIBarButtonItemStylePlain target:self action:@selector(presentImageUploadView)];
        
        // Register Photo Library changes
        [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];

        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(paletteChanged) name:kPiwigoNotificationPaletteChanged object:nil];
    }
    return self;
}


#pragma mark - View Lifecycle

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    if([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
    {
        [self setEdgesForExtendedLayout:UIRectEdgeNone];
    }
}

-(void)paletteChanged
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];
    
    // Navigation bar appearence
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    [self.navigationController.navigationBar setTintColor:[UIColor piwigoOrange]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor piwigoBackgroundColor]];
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    
    // Collection view
    self.localImagesCollection.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ?UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Set colors, fonts, etc.
    [self paletteChanged];
    
    // Update navigation bar and title
    [self updateNavBar];
    
    // Scale width of images on iPad so that they seem to adopt a similar size
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        CGFloat mainScreenWidth = MIN([UIScreen mainScreen].bounds.size.width,
                                     [UIScreen mainScreen].bounds.size.height);
        CGFloat currentViewWidth = MIN(self.view.bounds.size.width,
                                       self.view.bounds.size.height);
        self.nberOfImagesPerRow = roundf(currentViewWidth / mainScreenWidth * [Model sharedInstance].thumbnailsPerRowInPortrait);
    }
    else {
        self.nberOfImagesPerRow = [Model sharedInstance].thumbnailsPerRowInPortrait;
    }

    // Progress bar
    [ImageUploadProgressView sharedInstance].delegate = self;
    [[ImageUploadProgressView sharedInstance] changePaletteMode];
    
    if([ImageUploadManager sharedInstance].imageUploadQueue.count > 0)
    {
        [[ImageUploadProgressView sharedInstance] addViewToView:self.view forBottomLayout:self.bottomLayoutGuide];
    }
    
    // Reload collection (and display those being uploaded)
    [self.localImagesCollection reloadData];
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    //Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self updateNavBar];
        [self.localImagesCollection reloadData];
    } completion:nil];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    self.title = NSLocalizedString(@"alertCancelButton", @"Cancel");
}

-(void)updateNavBar
{
    switch (self.selectedImages.count) {
        case 0:
            self.navigationItem.leftBarButtonItems = @[];
            // Do not show two buttons provide enough space for title
            // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
            if(self.view.bounds.size.width <= 414) {     // i.e. smaller than iPhones 6,7 Plus screen width
                self.navigationItem.rightBarButtonItems = @[self.sortBarButton];
            }
            else {
                self.navigationItem.rightBarButtonItems = @[self.sortBarButton, self.uploadBarButton];
                [self.uploadBarButton setEnabled:NO];
            }
            self.title = NSLocalizedString(@"selectImages", @"Select Images");
            break;
            
        case 1:
            self.navigationItem.leftBarButtonItems = @[self.cancelBarButton];
            // Do not show two buttons provide enough space for title
            // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
            if(self.view.bounds.size.width <= 414) {     // i.e. smaller than iPhones 6,7 Plus screen width
                self.navigationItem.rightBarButtonItems = @[self.uploadBarButton];
            }
            else {
                self.navigationItem.rightBarButtonItems = @[self.sortBarButton, self.uploadBarButton];
            }
            [self.uploadBarButton setEnabled:YES];
            self.title = NSLocalizedString(@"selectImageSelected", @"1 Image Selected");
            break;
            
        default:
            self.navigationItem.leftBarButtonItems = @[self.cancelBarButton];
            // Do not show two buttons provide enough space for title
            // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
            if(self.view.bounds.size.width <= 414) {     // i.e. smaller than iPhones 6,7 Plus screen width
                self.navigationItem.rightBarButtonItems = @[self.uploadBarButton];
            }
            else {
                self.navigationItem.rightBarButtonItems = @[self.sortBarButton, self.uploadBarButton];
            }
            [self.uploadBarButton setEnabled:YES];
            self.title = [NSString stringWithFormat:NSLocalizedString(@"selectImagesSelected", @"%@ Images Selected"), @(self.selectedImages.count)];
            break;
    }
}


#pragma mark - Split & Sort Images

-(void)splitImages
{
    // Initialise collection data array
    self.imagesInSections = [NSMutableArray new];
    self.selectedSections = [NSMutableArray new];
    if ([self.images count] == 0) return;
    
    // Initialise loop conditions
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSInteger comps = (NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear);
    NSDateComponents *currentDateComponents = [calendar components:comps fromDate: [[self.images firstObject] creationDate]];
    NSDate *currentDate = [calendar dateFromComponents:currentDateComponents];
    NSMutableArray *imagesOfSameDate = [NSMutableArray new];
    
    // Loop over the whole image list
    for (PHAsset *imageAsset in self.images) {
        
        // Get current image creation date
        NSDateComponents *dateComponents = [calendar components:comps fromDate:imageAsset.creationDate];
        NSDate *date = [calendar dateFromComponents:dateComponents];
        
        // Images taken at another date?
        NSComparisonResult result = [date compare:currentDate];
        if (result == NSOrderedSame) {
            // Same date -> Append object to section
            [imagesOfSameDate addObject:imageAsset];
        }
        else {
            // Append section to collection
            [self.imagesInSections addObject:[imagesOfSameDate copy]];
            [self.selectedSections addObject:[NSNumber numberWithBool:NO]];
            
            // Initialise for next items
            [imagesOfSameDate removeAllObjects];
            currentDateComponents = [calendar components:comps fromDate: [imageAsset creationDate]];
            currentDate = [calendar dateFromComponents:currentDateComponents];
            
            // Add current item
            [imagesOfSameDate addObject:imageAsset];
        }
    }
    
    // Append last section to collection
    [self.imagesInSections addObject:[imagesOfSameDate copy]];
    [self.selectedSections addObject:[NSNumber numberWithBool:NO]];
}

-(void)askSortType
{
    UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"sortBy", @"Sort by")
            message:NSLocalizedString(@"imageSortMessage", @"Please select how you wish to sort images")
            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *cancelAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
            style:UIAlertActionStyleCancel
            handler:^(UIAlertAction * action) {}];
    
    UIAlertAction *newestAction = [UIAlertAction
            actionWithTitle:[SortLocalImages getNameForSortType:kPiwigoSortByNewest]
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {
               [self setSortType:kPiwigoSortByNewest];
            }];
    
    UIAlertAction* oldestAction = [UIAlertAction
            actionWithTitle:[SortLocalImages getNameForSortType:kPiwigoSortByOldest]
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction * action) {
               [self setSortType:kPiwigoSortByOldest];
            }];
    
    UIAlertAction* notUploadedAction = [UIAlertAction
            actionWithTitle:[SortLocalImages getNameForSortType:kPiwigoSortByNotUploaded]
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction * action) {
               [self setSortType:kPiwigoSortByNotUploaded];
            }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:newestAction];
    [alert addAction:oldestAction];
    [alert addAction:notUploadedAction];
    
    // Present list of actions
    alert.popoverPresentationController.barButtonItem = self.sortBarButton;
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)setSortType:(kPiwigoSortBy)sortType
{
    if(sortType != kPiwigoSortByNotUploaded && _sortType == kPiwigoSortByNotUploaded)
    {
        self.images = [[PhotosFetch sharedInstance] getImagesForAssetGroup:self.groupAsset];
    }
    
    _sortType = sortType;
    
    PiwigoAlbumData *downloadingCategory = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
    
    if(sortType == kPiwigoSortByNotUploaded)
    {
        if(!self.loadingView.superview)
        {
            self.loadingView = [LoadingView new];
            self.loadingView.translatesAutoresizingMaskIntoConstraints = NO;
            NSString *progressLabelFormat = [NSString stringWithFormat:@"%@ / %@", @"%d", @(downloadingCategory.numberOfImages)];
            self.loadingView.progressLabel.format = progressLabelFormat;
            self.loadingView.progressLabel.method = UILabelCountingMethodLinear;
            [self.loadingView showLoadingWithLabel:NSLocalizedString(@"downloadingImageInfo", @"Downloading Image Info") andProgressLabel:[NSString stringWithFormat:progressLabelFormat, 0]];
            [self.view addSubview:self.loadingView];
            [self.view addConstraints:[NSLayoutConstraint constraintCenterView:self.loadingView]];
            self.loadingView.hidden = YES;
            
            if(downloadingCategory.numberOfImages != downloadingCategory.imageList.count)
            {
                self.loadingView.hidden = NO;
                if(downloadingCategory.numberOfImages >= 100)
                {
                    [self.loadingView.progressLabel countFrom:0 to:100 withDuration:1];
                }
                else
                {
                    [self.loadingView.progressLabel countFrom:0 to:downloadingCategory.numberOfImages withDuration:1];
                }
            }
        }
    }
    
    __block NSDate *lastTime = [NSDate date];
    
    [SortLocalImages getSortedImageArrayFromSortType:sortType
                forImages:self.images
              forCategory:self.categoryId
              forProgress:^(NSInteger onPage, NSInteger outOf) {
                  
                  // Calculate the number of thumbnails displayed per page
                  NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:nil andNberOfImagesPerRowInPortrait:self.nberOfImagesPerRow];
                  
                  NSInteger lastImageCount = (onPage + 1) * imagesPerPage;
                  NSInteger currentDownloaded = (onPage + 2) * imagesPerPage;
                  
                  NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:lastTime];
                  
                  if(currentDownloaded > downloadingCategory.numberOfImages)
                  {
                      currentDownloaded = downloadingCategory.numberOfImages;
                  }
                  
                  [self.loadingView.progressLabel countFrom:lastImageCount to:currentDownloaded withDuration:duration];
                  
                  lastTime = [NSDate date];
              }
             onCompletion:^(NSArray *images) {
                 
                 if(sortType == kPiwigoSortByNotUploaded && !self.loadingView.hidden)
                 {
                     [self.loadingView hideLoadingWithLabel:NSLocalizedString(@"completeHUD_label", @"Complete") showCheckMark:YES withDelay:0.5];
                 }
                 self.images = images;
                 
                 // Refresh collection view
                 [self splitImages];
                 [self.localImagesCollection reloadData];
             }];
}


#pragma mark - Select Images

-(void)cancelSelect
{
    // Loop over all sections
    for (NSInteger section = 0; section < [self.localImagesCollection numberOfSections]; section++)
    {
        // Loop over images in section
        for (NSInteger row = 0; row < [self.localImagesCollection numberOfItemsInSection:section]; row++)
        {
            // Deselect image
            LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:(section+1)]];
            cell.cellSelected = NO;
        }
        
        // Update state of Select button
        [self.selectedSections replaceObjectAtIndex:section withObject:[NSNumber numberWithBool:NO]];
    }
    
    // Clear list of selected images
    self.selectedImages = [NSMutableArray new];
    
    // Update navigation bar
    [self updateNavBar];
    
    // Update collection
    [self.localImagesCollection reloadData];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
{
    // Will interpret touches only in horizontal direction
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIPanGestureRecognizer *gPR = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint translation = [gPR translationInView:self.localImagesCollection];
        if (fabs(translation.x) > fabs(translation.y))
            return YES;
    }
    return NO;
}

-(void)touchedImages:(UIPanGestureRecognizer *)gestureRecognizer
{
    // To prevent a crash
    if (gestureRecognizer.view == nil) return;
    
    // Select/deselect the cell or scroll the view
    if ((gestureRecognizer.state == UIGestureRecognizerStateBegan) ||
        (gestureRecognizer.state == UIGestureRecognizerStateChanged)) {
        
        // Point and direction
        CGPoint point = [gestureRecognizer locationInView:self.localImagesCollection];
        
        // Get item at touch position
        NSIndexPath *indexPath = [self.localImagesCollection indexPathForItemAtPoint:point];
        if ((indexPath.section == NSNotFound) || (indexPath.row == NSNotFound)) return;
        
        // Get cell at touch position
        UICollectionViewCell *cell = [self.localImagesCollection cellForItemAtIndexPath:indexPath];
        PHAsset *imageAsset = [[self.imagesInSections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        if ((cell == nil) || (imageAsset == nil)) return;
    
        // Only consider image cells
        if ([cell isKindOfClass:[LocalImageCollectionViewCell class]])
        {
            LocalImageCollectionViewCell *imageCell = (LocalImageCollectionViewCell *)cell;
            
            // Update the selection if not already done
            if (![self.touchedImages containsObject:imageAsset]) {
                
                // Store that the user touched this cell during this gesture
                [self.touchedImages addObject:imageAsset];
                
                // Update the selection state
                if(![self.selectedImages containsObject:imageAsset]) {
                    [self.selectedImages addObject:imageAsset];
                    imageCell.cellSelected = YES;
                } else {
                    imageCell.cellSelected = NO;
                    [self.selectedImages removeObject:imageAsset];
                }
                
                // Update navigation bar
                [self updateNavBar];

                // Update state of Select button if needed, and reload section
                [self updateSelectButtonForSection:indexPath.section];
            }
        }
    }

    // Is this the end of the gesture?
    if ([gestureRecognizer state] == UIGestureRecognizerStateEnded) {
        self.touchedImages = [NSMutableArray new];
    }
}

-(void)updateSelectButtonForSection:(NSInteger)section
{
    // Number of images in section
    NSInteger nberOfImages = [[self.imagesInSections objectAtIndex:section] count];
    
    // Count selected images in section
    NSInteger nberOfSelectedImages = 0;
    for (NSInteger item = 0; item < nberOfImages; item++) {
        
        // Retrieve image asset
        PHAsset *imageAsset = [[self.imagesInSections objectAtIndex:section] objectAtIndex:item];
        
        // Is this image selected?
        if ([self.selectedImages containsObject:imageAsset]) {
            nberOfSelectedImages++;
        }
    }
    
    // Update state of Select button
    if (nberOfImages == nberOfSelectedImages)
    {
        [self.selectedSections replaceObjectAtIndex:section withObject:[NSNumber numberWithBool:YES]];
    }
    else {
        [self.selectedSections replaceObjectAtIndex:section withObject:[NSNumber numberWithBool:NO]];
    }

    // Reload section
    [self.localImagesCollection reloadSections:[NSIndexSet indexSetWithIndex:section]];
}

-(void)presentImageUploadView
{
    // Present Image Upload View
    ImageUploadViewController *imageUploadVC = [ImageUploadViewController new];
    imageUploadVC.selectedCategory = self.categoryId;
    imageUploadVC.imagesSelected = self.selectedImages;
    [self.navigationController pushViewController:imageUploadVC animated:YES];

    // Clear list of selected images
    self.selectedImages = [NSMutableArray new];

    // Reset Select buttons
    for (NSInteger section = 0; section < self.imagesInSections.count; section++) {
        [self.selectedSections replaceObjectAtIndex:section withObject:[NSNumber numberWithBool:NO]];
    }
}

#pragma mark - UICollectionView - Headers

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    return CGSizeMake(collectionView.frame.size.width, 44.0);
}

-(UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if (self.images.count > 0) {
        // Display data in header of section
        ImagesHeaderReusableView *header = nil;
        
        if(kind == UICollectionElementKindSectionHeader)
        {
            UINib *nib = [UINib nibWithNibName:@"ImagesHeaderReusableView" bundle:nil];
            [collectionView registerNib:nib forCellWithReuseIdentifier:@"ImagesHeaderReusableView"];
            header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"ImagesHeaderReusableView" forIndexPath:indexPath];
            
            [header setupWithImages:[self.imagesInSections objectAtIndex:indexPath.section] inSection:indexPath.section andSelectionMode:[[self.selectedSections objectAtIndex:indexPath.section] boolValue]];
            header.headerDelegate = self;
            
            return header;
        }
    } else {
        // No images!
        if (indexPath.section == 0) {
            // Display "No Images"
            NoImagesHeaderCollectionReusableView *header = nil;
            
            if(kind == UICollectionElementKindSectionHeader)
            {
                header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"NoImagesHeaderCollection" forIndexPath:indexPath];
                header.noImagesLabel.textColor = [UIColor piwigoHeaderColor];
                
                return header;
            }
        }
    }

    UICollectionReusableView *view = [[UICollectionReusableView alloc] initWithFrame:CGRectZero];
    return view;
}


#pragma mark - UICollectionView - Sections

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return (self.imagesInSections.count);
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(10, kImageMarginsSpacing, 10, kImageMarginsSpacing);
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)kImageCellSpacing;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)kImageCellSpacing;
}


#pragma mark - UICollectionView - Rows

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [[self.imagesInSections objectAtIndex:section] count];
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Calculate the optimum image size
    CGFloat size = (CGFloat)[ImagesCollection imageSizeForView:collectionView andNberOfImagesPerRowInPortrait:self.nberOfImagesPerRow];

    return CGSizeMake(size, size);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Create cell
    LocalImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"LocalImageCollectionViewCell" forIndexPath:indexPath];
    PHAsset *imageAsset = [[self.imagesInSections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    [cell setupWithImageAsset:imageAsset andThumbnailSize:(CGFloat)[ImagesCollection imageSizeForView:collectionView andNberOfImagesPerRowInPortrait:self.nberOfImagesPerRow]];

    // For some unknown reason, the asset resource may be empty
    NSArray *resources = [PHAssetResource assetResourcesForAsset:imageAsset];
    NSString *originalFilename;
    if ([resources count] > 0) {
        originalFilename = ((PHAssetResource*)resources[0]).originalFilename;
    } else {
        // No filename => Build filename from 32 characters of local identifier
        NSRange range = [imageAsset.localIdentifier rangeOfString:@"/"];
        originalFilename = [[imageAsset.localIdentifier substringToIndex:range.location] stringByReplacingOccurrencesOfString:@"-" withString:@""];
        // Filename extension required by Piwigo so that it knows how to deal with it
        if (imageAsset.mediaType == PHAssetMediaTypeImage) {
            // Adopt JPEG photo format by default, will be rechecked
            originalFilename = [originalFilename stringByAppendingPathExtension:@"jpg"];
        } else if (imageAsset.mediaType == PHAssetMediaTypeVideo) {
            // Videos are exported in MP4 format
            originalFilename = [originalFilename stringByAppendingPathExtension:@"mp4"];
        } else if (imageAsset.mediaType == PHAssetMediaTypeAudio) {
            // Arbitrary extension, not managed yet
            originalFilename = [originalFilename stringByAppendingPathExtension:@"m4a"];
        }
    }

    // Add pan gesture recognition
    UIPanGestureRecognizer *imageSeriesRocognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(touchedImages:)];
    imageSeriesRocognizer.minimumNumberOfTouches = 1;
    imageSeriesRocognizer.maximumNumberOfTouches = 1;
    imageSeriesRocognizer.cancelsTouchesInView = NO;
    imageSeriesRocognizer.delegate = self;
    [cell addGestureRecognizer:imageSeriesRocognizer];
    cell.userInteractionEnabled = YES;

    // Cell state
    cell.cellSelected = [self.selectedImages containsObject:imageAsset];
    cell.cellUploading = [[ImageUploadManager sharedInstance].imageNamesUploadQueue containsObject:[originalFilename stringByDeletingPathExtension]];
//    if([self.selectedImages containsObject:imageAsset])
//    {
//        cell.cellSelected = YES;
//    }
//    else if ([[ImageUploadManager sharedInstance].imageNamesUploadQueue containsObject:[originalFilename stringByDeletingPathExtension]])
//    {
//        cell.cellUploading = YES;
//    }
    
    return cell;
}


#pragma mark - UICollectionViewDelegate Methods

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    LocalImageCollectionViewCell *selectedCell = (LocalImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
    
    // Image asset
    PHAsset *imageAsset = [[self.imagesInSections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    // Update cell and selection
    if(selectedCell.cellSelected)
    {    // Deselect the cell
        [self.selectedImages removeObject:imageAsset];
        selectedCell.cellSelected = NO;
    }
    else
    {    // Select the cell
        [self.selectedImages addObject:imageAsset];
        selectedCell.cellSelected = YES;
    }
    
    // Update navigation bar
    [self updateNavBar];

    // Update state of Select button and reload section
    [self updateSelectButtonForSection:indexPath.section];
}


#pragma mark - ImageUploadProgressDelegate Methods

-(void)imageProgress:(ImageUpload *)image onCurrent:(NSInteger)current forTotal:(NSInteger)total onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks iCloudProgress:(CGFloat)iCloudProgress
{
    NSLog(@"UploadViewController[imageProgress:]");
    NSInteger row = [self.images indexOfObject:image.imageAsset];
    LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
    
    CGFloat chunkPercent = 100.0 / totalChunks / 100.0;
    CGFloat onChunkPercent = chunkPercent * (currentChunk - 1);
    CGFloat pieceProgress = (CGFloat)current / total;
    CGFloat uploadProgress = onChunkPercent + (chunkPercent * pieceProgress);
    if(uploadProgress > 1)
    {
        uploadProgress = 1;
    }
    
    cell.cellUploading = YES;
    if (iCloudProgress < 0) {
        cell.progress = uploadProgress;
        NSLog(@"UploadViewController[ImageProgress]: %.2f", uploadProgress);
    } else {
        cell.progress = (iCloudProgress + uploadProgress) / 2.0;
        NSLog(@"UploadViewController[ImageProgress]: %.2f", ((iCloudProgress + uploadProgress) / 2.0));
    }
}

-(void)imageUploaded:(ImageUpload *)image placeInQueue:(NSInteger)rank outOf:(NSInteger)totalInQueue withResponse:(NSDictionary *)response
{
    NSLog(@"UploadViewController[imageUploaded:]");
    NSInteger row = [self.images indexOfObject:image.imageAsset];
    LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
    
    // Image upload ended, deselect cell
    cell.cellUploading = NO;
    cell.cellSelected = NO;
    
    // Update list of "Not Uploaded" images
    if(self.sortType == kPiwigoSortByNotUploaded)
    {
        NSMutableArray *newList = [self.images mutableCopy];
        [newList removeObject:image.imageAsset];
        self.images = newList;
        
        // Update image collection
        [self.localImagesCollection reloadData];
    }
}


#pragma mark - SortSelectViewControllerDelegate Methods

-(void)didSelectSortTypeOf:(kPiwigoSortBy)sortType
{
    // Sort images according to new choice
    self.sortType = sortType;
}


#pragma mark - Changes occured in the Photo library

- (void)photoLibraryDidChange:(PHChange *)changeInfo {
    // Photos may call this method on a background queue;
    // switch to the main queue to update the UI.
    dispatch_async(dispatch_get_main_queue(), ^{
        // Collect new list of images
        self.images = [[PhotosFetch sharedInstance] getImagesForAssetGroup:self.groupAsset];

        // Sort images according to current choice
        [self setSortType:self.sortType];
    });
}


#pragma mark - Selected/deselected all images of section

-(void)didSelectImagesOfSection:(NSInteger)section
{
    // Change selection mode of section
    BOOL wasSelected = [[self.selectedSections objectAtIndex:section] boolValue];
    if (wasSelected) {
        [self.selectedSections replaceObjectAtIndex:section withObject:[NSNumber numberWithBool:NO]];
    }
    else {
        [self.selectedSections replaceObjectAtIndex:section withObject:[NSNumber numberWithBool:YES]];
    }
    
    // Number of images in section
    NSInteger nberOfImages = [[self.imagesInSections objectAtIndex:section] count];
    
    // Loop over all items in group
    for (NSInteger item = 0; item < nberOfImages; item++) {
        
        // Corresponding image asset
        PHAsset *imageAsset = [[self.imagesInSections objectAtIndex:section] objectAtIndex:item];
        
        // Corresponding collection view cell
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
        LocalImageCollectionViewCell *selectedCell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:indexPath];
        
        // Select or deselect cell
        if (wasSelected)
        {    // Deselect the cell
            if ([self.selectedImages containsObject:imageAsset]) {
                [self.selectedImages removeObject:imageAsset];
                selectedCell.cellSelected = NO;
            }
        }
        else
        {    // Select the cell
            if (![self.selectedImages containsObject:imageAsset]) {
                [self.selectedImages addObject:imageAsset];
                selectedCell.cellSelected = YES;
            }
        }
    }

    // Update navigation bar
    [self updateNavBar];
    
    // Reload section
    [self.localImagesCollection reloadSections:[NSIndexSet indexSetWithIndex:section]];
}

@end

