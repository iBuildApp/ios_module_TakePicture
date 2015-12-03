/****************************************************************************
 *                                                                           *
 *  Copyright (C) 2014-2015 iBuildApp, Inc. ( http://ibuildapp.com )         *
 *                                                                           *
 *  This file is part of iBuildApp.                                          *
 *                                                                           *
 *  This Source Code Form is subject to the terms of the iBuildApp License.  *
 *  You can obtain one at http://ibuildapp.com/license/                      *
 *                                                                           *
 ****************************************************************************/

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <FacebookSDK/FacebookSDK.h>
#import <MessageUI/MessageUI.h>
#import <FHSTwitterEngine/FHSTwitterEngine.h>

/**
 *  Main module class for widget mTakePicture (Take a picture). Module entry point.
 */
@interface mTakePictureViewController : UIViewController <UINavigationControllerDelegate,
                                                          UIImagePickerControllerDelegate,
                                                          MFMailComposeViewControllerDelegate,
                                                          UIAlertViewDelegate,
                                                          NSXMLParserDelegate>
{
  UIActivityIndicatorView *act;
  UIBarButtonItem *shareButton;
  UIToolbar *toolBar;
  UIImage *capturedImage;
  NSString * currentElement;
  
}

/**
 *  ImagePicker Controller
 */
@property (nonatomic, strong) UIImagePickerController *imgPicker;

/**
 *  Activate camera. Ready to get image
 */
- (void)cameraInit;

/**
 *  Set widget parameters
 *
 *  @param params dictionary with parameters
 */
- (void)setParams:(NSDictionary *)params;

@end