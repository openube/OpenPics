//
//  OPCollectionViewDataSource.m
//  OpenPics
//
//  Created by PJ Gray on 5/4/14.
//  Copyright (c) 2014 Say Goodnight Software. All rights reserved.
//

#import "OPCollectionViewDataSource.h"
#import "OPContentCell.h"
#import "OPProviderController.h"
#import "OPProvider.h"
#import "OPImageManager.h"
#import "OPImageCollectionViewController.h"
#import "OPNavigationControllerDelegate.h"
#import "OPSetCollectionViewDataSource.h"
#import "OPRedditGenericProvider.h"

@interface OPCollectionViewDataSource () <OPContentCellDelegate> {
    OPImageManager* _imageManager;
}

@end

@implementation OPCollectionViewDataSource

- (instancetype) init {
    self = [super init];
    if (self) {
        _items = [NSMutableArray array];
        self.currentQueryString = @"";

        _imageManager = [[OPImageManager alloc] init];
        _imageManager.delegate = self;
    }
    return self;
}

- (void) clearData {
    _canLoadMore = NO;
    _currentPage = [NSNumber numberWithInteger:1];
    _items = [@[] mutableCopy];
}

- (void) doInitialSearchWithSuccess:(void (^)(NSArray* items, BOOL canLoadMore))success
                            failure:(void (^)(NSError* error))failure {
    
    OPProvider* selectedProvider = [[OPProviderController shared] getSelectedProvider];
    _currentPage = [NSNumber numberWithInteger:1];
    
    [selectedProvider doInitialSearchWithSuccess:^(NSArray *items, BOOL canLoadMore) {
        _canLoadMore = canLoadMore;
        _items = items.mutableCopy;
        if (success) {
            success(items,canLoadMore);
        }
    } failure:^(NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
}

- (void) getMoreItemsWithSuccess:(void (^)(NSArray* indexPaths))success
                         failure:(void (^)(NSError* error))failure {
    _canLoadMore = NO;
    OPProvider* selectedProvider = [[OPProviderController shared] getSelectedProvider];
    [selectedProvider getItemsWithQuery:self.currentQueryString withPageNumber:_currentPage success:^(NSArray *items, BOOL canLoadMore) {
        if ([_currentPage isEqual:@1]) {
            _canLoadMore = canLoadMore;
            _items = items.mutableCopy;
            if (success) {
                success(nil);
            }
        } else {
            NSInteger offset = [_items count];
            
            // TODO: use performBatch when bug is fixed in UICollectionViews with headers
            NSMutableArray* indexPaths = [NSMutableArray array];
            for (int i = 0; i < items.count; i++) {
                [indexPaths addObject:[NSIndexPath indexPathForItem:i+offset inSection:0]];
            }
            [_items addObjectsFromArray:items];
            _canLoadMore = canLoadMore;
            if (success) {
                success(indexPaths);
            }
        }
    } failure:^(NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section;
{
    return [_items count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    
    OPItem* item = _items[indexPath.item];

    OPContentCell *cell;
    
    if (item.isImageSet.boolValue) {
        cell = (OPContentCell *)[cv dequeueReusableCellWithReuseIdentifier:@"setitem" forIndexPath:indexPath];
    } else {
        cell = (OPContentCell *)[cv dequeueReusableCellWithReuseIdentifier:@"imageitem" forIndexPath:indexPath];
    }
    
    // remove activity indicator if present
    for (UIView* subview in cell.contentView.subviews) {
        if (subview.tag == -1) {
            [subview removeFromSuperview];
        }
    }
    
    cell.internalScrollView.imageView.image = [UIImage imageNamed:@"transparent"];
    cell.provider = nil;
    cell.item = nil;
    cell.indexPath = nil;
    
    if (indexPath.item == (_items.count-1)) {
        if (_items.count) {
            if (_canLoadMore) {
                NSInteger currentPageInt = [_currentPage integerValue];
                _currentPage = [NSNumber numberWithInteger:currentPageInt+1];
                [self getMoreItemsWithSuccess:^(NSArray *indexPaths) {
                    [cv insertItemsAtIndexPaths:indexPaths];
                } failure:nil];
            }
        }
    }
    
    // remove the IB constraints cause they don't seem to work right - but I don't want them autogenerated
    [cell removeConstraints:cell.constraints];
    
    // set the frame to the contentView frame
    cell.internalScrollView.frame = cell.contentView.frame;
    
    // create constraints from autosizing
    cell.internalScrollView.translatesAutoresizingMaskIntoConstraints = YES;
    [cell.internalScrollView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    
    
    cell.provider = [[OPProviderController shared] getSelectedProvider];
    cell.item = item;
    cell.indexPath = indexPath;
    cell.internalScrollView.userInteractionEnabled = NO;
    cell.delegate = self;
    
    // HAAAACK
    if ((cell.frame.size.width > 250) && (![[OPNavigationControllerDelegate shared] transitioning] || (item.providerType == OPProviderTypeRedditGeneric))) {
        
        NSLog(@"greater than 250");
        [_imageManager loadImageFromItem:item
                             toImageView:cell.internalScrollView.imageView
                             atIndexPath:indexPath
                        onCollectionView:cv
                         withContentMode:UIViewContentModeScaleAspectFit
                          withCompletion:^{
                              [cell setupForSingleImageLayoutAnimated:NO];
                          }];
    } else {
        NSLog(@"less than 250");
        
        [_imageManager loadImageFromItem:item
                             toImageView:cell.internalScrollView.imageView
                             atIndexPath:indexPath
                        onCollectionView:cv
                         withContentMode:UIViewContentModeScaleAspectFill
                          withCompletion:nil];
    }
    
    return cell;
}

#pragma mark OPContentCellDelegate

- (void) singleTappedCell {
    if (self.delegate && [self.delegate respondsToSelector:@selector(singleTappedCell)]) {
        [self.delegate singleTappedCell];
    }
}

- (void) showProgressWithBytesRead:(NSUInteger) bytesRead
                withTotalBytesRead:(NSInteger) totalBytesRead
      withTotalBytesExpectedToRead:(NSInteger) totalBytesExpectedToRead {
    if (self.delegate && [self.delegate respondsToSelector:@selector(showProgressWithBytesRead:withTotalBytesRead:withTotalBytesExpectedToRead:)]) {
        [self.delegate showProgressWithBytesRead:bytesRead withTotalBytesRead:totalBytesRead withTotalBytesExpectedToRead:totalBytesExpectedToRead];
    }
}

- (OPItem*)itemAtIndexPath:(NSIndexPath*)indexPath {
    if (indexPath.item < _items.count) {
        return _items[indexPath.item];
    }
    
    return nil;
}

- (void) cancelRequestAtIndexPath:(NSIndexPath*)indexPath {
    [_imageManager cancelImageOperationAtIndexPath:indexPath];
}

- (void) cancelAll {
    [_imageManager cancelAllDataTasks];
}

@end
