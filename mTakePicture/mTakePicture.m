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

#import "mTakePicture.h"
#import "functionLibrary.h"
#import "reachability.h"
#import "TBXML.h"
#import "uiimage+resize.h"
#import "twitterid.h"
#import "auth_Share.h"

#define kConnectionCheckHostnameGoogle @"www.google.com"

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

#define kSaveButtonBorderColor [UIColor colorWithRed:((float)0x4E)/0x100 green:((float)0xAC)/0x100 blue:((float)0x18)/0x100 alpha:1.0f]
#define kFacebookButtonBackgroundColor [UIColor colorWithRed:((float)0x47)/0x100 green:((float)0x59)/0x100 blue:((float)0x95)/0x100 alpha:1.0f]
#define kTwitterButtonBackgroundColor [UIColor colorWithRed:((float)0x33)/0x100 green:((float)0xB5)/0x100 blue:((float)0xEB)/0x100 alpha:1.0f]
#define kEmailButtonBackgroundColor [UIColor colorWithRed:((float)0x00)/0x100 green:((float)0x84)/0x100 blue:((float)0xCA)/0x100 alpha:1.0f]
#define kSocialToolbarBackgroundColor [[UIColor blackColor] colorWithAlphaComponent:0.3f]
#define kSaveButtonBackgroundColor [UIColor clearColor]


#define kSaveButtonBorderWidth 1.0f
#define kSocialButtonCornerRadius 4.0f

#define kSocialButtonHeight 44.0f
#define kSocialButtonWidth kSocialButtonHeight
#define kSocialToolbarHeight 64.0f
#define kSocialButtonOriginY (kSocialToolbarHeight - kSocialButtonHeight) / 2

#define kSpaceBetweenSocialButtons 16.0f
#define kSocialButtonPaddingLeft 14.0f
#define kSocialButtonPaddingRight kSocialButtonPaddingLeft

@interface mTakePictureViewController()
{
  auth_Share *aSha;
}

@property (nonatomic, assign) BOOL          tabBarIsHidden;
@property (nonatomic, strong) NSDictionary *properties;
@property (nonatomic, strong) UIView       *panel;
@property (nonatomic, strong) UIButton     *cameraButton;
@property (nonatomic, strong) UIButton     *save;
@property (nonatomic, strong) UIButton     *retakeButton;
@property (nonatomic, strong) UIImageView  *resultingImageView;

@property (nonatomic, strong) FHSTwitterEngine *engine;

@property (nonatomic, strong) Reachability    *internetReachable;
@property (nonatomic, strong) Reachability    *hostReachable;
@property (nonatomic, assign) BOOL             bInet;             // Presence or absence of network

@property (nonatomic, strong) UIButton        *shareFacebookButton;
@property (nonatomic, strong) UIButton        *shareTwitterButton;
@property (nonatomic, strong) UIButton        *shareEmailButton;


@property (nonatomic, strong) NSMutableData   *receivedData;
@property (nonatomic, strong) NSURLConnection *postURLConnection;
@property (nonatomic, assign) BOOL             showLink;

@property (nonatomic, strong) NSData  *resultingImageData;

@end

@implementation mTakePictureViewController

@synthesize showLink,
imgPicker,
tabBarIsHidden,
properties,
panel,
save,
retakeButton,
resultingImageView,
bInet,
shareFacebookButton = _shareFacebookButton,
shareTwitterButton = _shareTwitterButton,
shareEmailButton = _shareEmailButton,
internetReachable = _internetReachable,
hostReachable     = _hostReachable,
postURLConnection = _postURLConnection,
receivedData = _receivedData,
engine = _engine;


/**
 *  Special parser for processing original xml file
 *
 *  @param xmlElement_ NSValue* xmlElement_
 *  @param params_     NSMutableDictionary* params_
 */
+ (void)parseXML:(NSValue *)xmlElement_
      withParams:(NSMutableDictionary *)params_
{
  TBXMLElement element;
  [xmlElement_ getValue:&element];
  
  NSMutableArray *contentArray = [[NSMutableArray alloc] init];
  
  NSString *szTitle = @"";
  TBXMLElement *titleElement = [TBXML childElementNamed:@"title" parentElement:&element];
  if ( titleElement )
    szTitle = [TBXML textForElement:titleElement];
  
  // 1. adding a zero element to array
  [contentArray addObject:[NSDictionary dictionaryWithObject:szTitle ? szTitle : @"" forKey:@"title" ] ];
  
  // 2. search for tag <button>
  TBXMLElement *objectElement = [TBXML childElementNamed:@"button" parentElement:&element];
  while ( objectElement )
  {
    NSMutableDictionary *objDictionary = [[NSMutableDictionary alloc] init];
    // search for tags <type>, <email>, <label> inside of tag <object>
    NSArray *tags = [NSArray arrayWithObjects:@"type", @"email", @"label", nil];
    TBXMLElement *tagElement = objectElement->firstChild;
    while( tagElement )
    {
      NSString *szTag = [[TBXML elementName:tagElement] lowercaseString];
      
      for( NSString *str in tags )
      {
        if ( [szTag isEqual:str] )
        {
          NSString *tagContent = [TBXML textForElement:tagElement];
          if ( [tagContent length] )
            [objDictionary setObject:tagContent forKey:szTag];
          break;
        }
      }
      tagElement = tagElement->nextSibling;
    }
    // save dictionary to array
    if ( [objDictionary count] )
      [contentArray addObject:objDictionary];
    objectElement = [TBXML nextSiblingNamed:@"button" searchFromElement:objectElement];
  }
  
  [params_ setObject:contentArray forKey:@"data"];
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if ( self )
  {
    self.params = nil;
    self.panel  = nil;
    self.save   = nil;
    self.retakeButton = nil;
    self.cameraButton = nil;
    self.resultingImageView  = nil;
    self.imgPicker   = nil;
    
    self.bInet        = NO;
    self.resultingImageData = nil;
    
    _shareFacebookButton = nil;
    _shareTwitterButton  = nil;
    _shareEmailButton    = nil;
    
    _engine            = nil;
    _internetReachable = nil;
    _hostReachable     = nil;
    
    _postURLConnection = nil;
    _receivedData      = nil;
    
    aSha = [auth_Share sharedInstance];
    aSha.messageProcessingBlock = nil;
  }
  return self;
}

- (void)dealloc
{
  self.params = nil;
  
  
  
  
  
  
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
}

- (void)setParams:(NSDictionary *)params_
{
  self.properties = params_;
  self.showLink = [[params_ objectForKey:@"showLink"] isEqual:@"1"];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
  self.internetReachable = [Reachability reachabilityForInternetConnection];
  [self.internetReachable startNotifier];
  
  // check if a pathway to a google host exists
  self.hostReachable = [Reachability reachabilityWithHostName:kConnectionCheckHostnameGoogle];
  [self.hostReachable startNotifier];
  
  // check for internet connection state
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(checkNetworkStatus:)
                                               name:kReachabilityChangedNotification
                                             object:nil];
  
  [self cameraInit];
  
  [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
  self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  self.view.autoresizesSubviews = YES;
  
  self.view.backgroundColor = [UIColor blackColor];
  
  if ( self.properties )
  {
    NSArray *dataParams = [self.properties objectForKey:@"data"];
    [self.navigationItem setTitle:[[dataParams objectAtIndex:0] objectForKey:@"title"] ];
  }
  
  [self hideTabBar];
  
  [super viewWillAppear:animated];
}

-(void)showNavigationBarAnimated:(BOOL)animated
{
  [self.navigationItem setHidesBackButton:NO animated:NO];
  [self.navigationController setNavigationBarHidden:NO animated:NO];
  [[self.navigationController navigationBar] setBarStyle:UIBarStyleDefault];
  [[self.navigationController navigationBar] setOpaque  :YES];
  [[self.navigationController navigationBar] setAlpha   :1.f];
}


-(void)viewDidAppear:(BOOL)animated
{
  if(self.isMovingToParentViewController || self.isBeingPresented){
    [self showNavigationBarAnimated:animated];
  }
  [super viewDidAppear:animated];
}

-(void)hideTabBar{
  // hide tabBar on viewDidAppear
  // before hiding / displaying tabBar we must remember its previous state
  self.tabBarIsHidden = [[self.tabBarController tabBar] isHidden];
  if ( !self.tabBarIsHidden ){
    [[self.tabBarController tabBar] setHidden:YES];
  }
}

-(void)showTabBar{
  // restore tabBar state
  [[self.tabBarController tabBar] setHidden:self.tabBarIsHidden];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
  if(self.isMovingFromParentViewController || self.isBeingDismissed){
    [self showTabBar];
  }
}

- (void)viewDidUnload
{
  shareButton = nil;
  toolBar = nil;
  [super viewDidUnload];
}


#pragma mark - UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
  [self.navigationController popViewControllerAnimated:YES];
}


#pragma mark - Camera

- (void)cameraInit
{
  if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
  {
    [self placeImgPicker];
    
    [self setStatusBarHidden];
    
    if([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear] &&
       [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront])
    {
      [self placeCameraSwitch];
    }
    [self placeCameraButton];
  }
  else
  {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSBundleLocalizedString(@"mTP_noCameraTitle", @"No Camera Available")
                                                    message:NSBundleLocalizedString(@"mTP_noCameraMessage", @"Requires a camera to take pictures")
                                                   delegate:self
                                          cancelButtonTitle:NSBundleLocalizedString(@"mTP_noCameraOkButtonTitle", @"OK")
                                          otherButtonTitles:nil];
    [alert show];
    return;
  }
}

-(void)setStatusBarHidden
{
  // set statusBarHidden after delay!
  BOOL bHidden = NO;
  SEL selector = @selector(setStatusBarHidden:);
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                              [[[UIApplication sharedApplication] class] instanceMethodSignatureForSelector:selector]];
  // first parameter for index has index 2 !!!
  [invocation setArgument:&bHidden atIndex:2];
  [invocation setSelector:@selector(setStatusBarHidden:)];
  [invocation setTarget:[UIApplication sharedApplication]];
  [NSTimer scheduledTimerWithTimeInterval:0.1 invocation:invocation repeats:NO];
}

-(void)placeImgPicker
{
  [[self.imgPicker view] removeFromSuperview];
  self.imgPicker = [[UIImagePickerController alloc] init];
  
  self.imgPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
  
  self.imgPicker.allowsEditing       = NO;
  self.imgPicker.showsCameraControls = NO;
  self.imgPicker.delegate            = self;
  self.imgPicker.videoQuality          = UIImagePickerControllerQualityTypeHigh;
  self.imgPicker.view.frame            = self.view.bounds;
  self.imgPicker.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  
  CGSize viewSize = [UIScreen mainScreen].bounds.size;
  
  CGFloat cameraAspectRatio = 4.0 / 3.0;
  CGFloat imageWidth = floorf(viewSize.width * cameraAspectRatio);
  CGFloat scale = ceilf((viewSize.height / imageWidth) * 10.0) / 10.0;
  
  self.imgPicker.cameraViewTransform = CGAffineTransformMakeScale(scale, scale);
  
  [self.view addSubview:self.imgPicker.view];
  
  [self.imgPicker viewWillAppear:YES];
  [self.imgPicker viewDidAppear:YES];
}

-(void)placeCameraButton
{
  self.cameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
  self.cameraButton.frame = CGRectMake(120.0f, self.imgPicker.view.frame.size.height - 52.0f, 80.0f, 42.0f);
  self.cameraButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
  [self.cameraButton setBackgroundImage:[UIImage imageNamed:resourceFromBundle(@"mTP_buttonBG")] forState:UIControlStateNormal];
  self.cameraButton.layer.borderColor = [UIColor lightGrayColor].CGColor;
  self.cameraButton.layer.borderWidth = 1.0f;
  self.cameraButton.layer.cornerRadius = 18.0f;
  self.cameraButton.layer.masksToBounds = YES;
  self.cameraButton.alpha = 0.7f;
  [self.cameraButton addTarget:self action:@selector(takePicture) forControlEvents:UIControlEventTouchUpInside];
  UIImage *cameraIcon = [UIImage imageNamed:resourceFromBundle(@"mTP_cameraButton")];
  UIImageView *cameraIconView = [[UIImageView alloc] initWithImage:cameraIcon];
  cameraIconView.frame = CGRectMake( (self.cameraButton.frame.size.width - cameraIcon.size.width) / 2,
                                    (self.cameraButton.frame.size.height - cameraIcon.size.height) / 2,
                                    cameraIcon.size.width,
                                    cameraIcon.size.height);
  [self.cameraButton addSubview:cameraIconView];
  [self.imgPicker.view addSubview:self.cameraButton];
}

-(void)placeCameraSwitch
{
  UIButton *cameraSwitch = [UIButton buttonWithType:UIButtonTypeCustom];
  cameraSwitch.frame = CGRectMake(250.0f, 10.0f, 60.0f, 36.0f);
  [cameraSwitch setBackgroundImage:[UIImage imageNamed:resourceFromBundle(@"mTP_buttonBG")] forState:UIControlStateNormal];
  cameraSwitch.layer.borderColor = [UIColor lightGrayColor].CGColor;
  cameraSwitch.layer.borderWidth = 1.0f;
  cameraSwitch.layer.cornerRadius = 16.0f;
  cameraSwitch.layer.masksToBounds = YES;
  cameraSwitch.alpha = 0.7f;
  [cameraSwitch addTarget:self action:@selector(_cameraSwitch) forControlEvents:UIControlEventTouchUpInside];
  UIImage *toggleIcon = [UIImage imageNamed:resourceFromBundle(@"mTP_switchButton")];
  UIImageView *toggleIconView = [[UIImageView alloc] initWithImage:toggleIcon];
  toggleIconView.frame = CGRectMake( (cameraSwitch.frame.size.width - toggleIcon.size.width) / 2,
                                    (cameraSwitch.frame.size.height - toggleIcon.size.height) / 2,
                                    toggleIcon.size.width,
                                    toggleIcon.size.height );
  [cameraSwitch addSubview:toggleIconView];
  [self.imgPicker.view addSubview:cameraSwitch];
}

/**
 *  Switch camera (front or back)
 */
- (void)_cameraSwitch
{
  if(self.imgPicker.cameraDevice == UIImagePickerControllerCameraDeviceFront)
  {
    self.imgPicker.cameraDevice = UIImagePickerControllerCameraDeviceRear;
  }
  else
  {
    self.imgPicker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
  }
}

-(void)takePicture
{
  self.view.userInteractionEnabled = NO;
  
  [self.imgPicker takePicture];
}

#pragma mark - Save Image
- (void)_save
{
  [self.save setEnabled:NO];
  UIImageWriteToSavedPhotosAlbum([UIImage imageWithData:self.resultingImageData],
                                 self,
                                 @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:),
                                 nil );
}

- (void)thisImage:(UIImage *)image hasBeenSavedInPhotoAlbumWithError:(NSError *)error usingContextInfo:(void*)ctxInfo {
  if (error){
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSBundleLocalizedString(@"mTP_errorSavingPhotoTitle", @"Error!")
                                                    message:NSBundleLocalizedString(@"mTP_errorSavingPhotoMessage", @"Can't save the image!")
                                                   delegate:nil
                                          cancelButtonTitle:NSBundleLocalizedString(@"mTP_errorSavingPhotoOkButtonTitle", @"OK")
                                          otherButtonTitles:nil];
    [alert show];
  } else {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                    message:NSBundleLocalizedString(@"mTP_successSavingPhotoMessage", @"The picture has been saved to your iPhone.")
                                                   delegate:nil
                                          cancelButtonTitle:NSBundleLocalizedString(@"mTP_successSavingPhotoOkButtonTitle", @"OK")
                                          otherButtonTitles:nil];
    [alert show];
  }
  save.enabled = YES;
}

#pragma mark - Share Actions
- (void)shareFacebook
{
  [self shareImageWithServiceType:auth_ShareServiceTypeFacebook];
}

- (void)shareTwitter
{
  [self shareImageWithServiceType:auth_ShareServiceTypeTwitter];
}

-(void)shareImageWithServiceType:(auth_ShareServiceType)serviceType
{
  NSMutableDictionary *data = [NSMutableDictionary dictionary];

  if(serviceType == auth_ShareServiceTypeFacebook){
    
    [data setObject:self.resultingImageData forKey:@"source"];
    [data setObject:@"/me/photos" forKey:@"graphPath"];

  } else if(serviceType == auth_ShareServiceTypeTwitter){
    
    [data setObject:self.resultingImageData forKey:@"imageData"];

  }
  
  aSha.delegate = nil;
  aSha.viewController = self;
  [aSha shareContentUsingService:serviceType fromUser:aSha.user withData:data showLoginRequiredPrompt:NO];
}

- (void)shareEmail
{
  if ( !self.properties )
    return;
  
  NSArray *dataParams = [self.properties objectForKey:@"data"];
  if ( [dataParams count] < 2 )
    return;
  
  NSString *address = [[dataParams objectAtIndex:1] objectForKey:@"email"];
  
  NSString *sendText = NSBundleLocalizedString(@"mTP_sharePhotoEmailSubject", @"New picture from camera");
  
  [functionLibrary callMailComposerWithRecipients:address ? [NSArray arrayWithObject:address] : nil
                                       andSubject:NSBundleLocalizedString(@"mTP_sharePhotoEmailSubject", @"New picture from camera")
                                          andBody:sendText
                                           asHTML:YES
                                   withAttachment:self.resultingImageData
                                         mimeType:@"image/jpeg"
                                         fileName:@"CameraImage"
                                   fromController:self
                                         showLink:showLink];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)composeResult
                        error:(NSError *)error
{
  switch (composeResult)
  {
    case MFMailComposeResultCancelled:
      break;
      
    case MFMailComposeResultSaved:
      break;
      
    case MFMailComposeResultSent:
      break;
      
    case MFMailComposeResultFailed:
    {
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"general_sendingEmailFailedAlertTitle", @"Error sending email") //@"Error sending sms"
                                                      message:NSLocalizedString(@"general_sendingEmailFailedAlertMessage", @"Error sending email") //@"Error sending sms"
                                                     delegate:nil
                                            cancelButtonTitle:NSLocalizedString(@"general_sendingEmailFailedAlertOkButtonTitle", @"OK") //@"OK"
                                            otherButtonTitles:nil];
      [alert show];
    }
      break;
      
    default:
      break;
  }
  [self dismissViewControllerAnimated:YES completion:nil];
}


- (void)successfullySent:(NSString*)msgString
{
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                  message:msgString
                                                 delegate:nil
                                        cancelButtonTitle:NSBundleLocalizedString(@"mTP_sendingEmailSuccessAlertOkButtonTitle", @"OK")
                                        otherButtonTitles:nil];
  [alert show];
}


#pragma mark - ImagePicker
- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info
{
  UIImage *resultingImage = [info objectForKey:@"UIImagePickerControllerOriginalImage"];

  CGFloat shrinkFactor = 1.0f;
  
  UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
  
  if(UIInterfaceOrientationIsPortrait(orientation)){
    shrinkFactor = self.view.bounds.size.height / resultingImage.size.height;
  } else {
    shrinkFactor = self.view.bounds.size.width / resultingImage.size.width;
  }
  
  // resize image
  CGSize smallImageSize = (CGSize){ceilf(resultingImage.size.width * shrinkFactor), ceilf(resultingImage.size.height * shrinkFactor)};
  
  UIImage *smallImage = [resultingImage resizedImageWithContentMode:UIViewContentModeScaleAspectFit
                                                          bounds:smallImageSize
                                            interpolationQuality:kCGInterpolationDefault];
  
  UIImage *uploadableImage = [self prepareUploadableImageWithImage:resultingImage];
  
  self.resultingImageData = UIImageJPEGRepresentation(uploadableImage, 0.9);
  
  
  self.view.userInteractionEnabled = YES;
  
  [self.resultingImageView removeFromSuperview];
  self.resultingImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
  self.resultingImageView.autoresizesSubviews = YES;
  self.resultingImageView.autoresizingMask    = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.resultingImageView.contentMode         = UIViewContentModeCenter;//ScaleAspectFit;
  self.resultingImageView.image               = smallImage;
  
  // remove imagePicker
  [self.imgPicker.view removeFromSuperview];
  [self.imgPicker viewWillDisappear:NO];
  [self.imgPicker viewDidDisappear:NO];
  self.imgPicker = nil;
  
  self.view.backgroundColor = [UIColor darkGrayColor];
  [self.view addSubview:self.resultingImageView];
  
  [self.retakeButton removeFromSuperview];
  self.retakeButton = [UIButton buttonWithType:UIButtonTypeCustom];
  self.retakeButton.frame = CGRectMake(210.0f, 10.0f, 100.0f, 36.0f);
  [self.retakeButton setBackgroundImage:[UIImage imageNamed:resourceFromBundle(@"mTP_buttonBG")] forState:UIControlStateNormal];
  self.retakeButton.layer.borderColor = [UIColor lightGrayColor].CGColor;
  self.retakeButton.layer.borderWidth = 1.0f;
  self.retakeButton.layer.cornerRadius = 16.0f;
  self.retakeButton.layer.masksToBounds = YES;
  self.retakeButton.alpha = 0.6f;
  self.retakeButton.layer.backgroundColor = [UIColor colorWithRed:0.7f green:0.2f blue:0.1f alpha:1.0f].CGColor;
  [self.retakeButton addTarget:self action:@selector(cameraInit) forControlEvents:UIControlEventTouchUpInside];
  UIImage *retakeIcon = [UIImage imageNamed:resourceFromBundle(@"mTP_cameraButton")];
  UIImageView *retakeIconView = [[UIImageView alloc] initWithImage:retakeIcon];
  retakeIconView.frame = CGRectMake(8.0f, (self.retakeButton.frame.size.height - retakeIcon.size.height) / 2, retakeIcon.size.width, retakeIcon.size.height);
  [self.retakeButton addSubview:retakeIconView];
  self.retakeButton.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
  [self.retakeButton setTitle:[@"       " stringByAppendingString:NSBundleLocalizedString(@"mTP_retake", @"Retake")] forState:UIControlStateNormal];
  [self.retakeButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
  self.retakeButton.titleLabel.shadowOffset = CGSizeMake (0.0f, -1.0f);
  [self.retakeButton setTitleShadowColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
  [self.view addSubview:self.retakeButton];
  
  const CGFloat panelHeight = kSocialToolbarHeight;
  
  [self.panel removeFromSuperview];
  self.panel = [[UIView alloc] initWithFrame:CGRectMake(0.0f, self.view.frame.size.height, self.view.frame.size.width, 0.0f)];
  self.panel.autoresizesSubviews = YES;
  self.panel.autoresizingMask    = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
  self.panel.backgroundColor     = [UIColor clearColor];
  [self.view addSubview:self.panel];
  
  UIView *panelBackground = [[UIView alloc] initWithFrame:self.panel.bounds];
  panelBackground.autoresizesSubviews = YES;
  panelBackground.autoresizingMask    = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  panelBackground.backgroundColor     = kSocialToolbarBackgroundColor;
  [self.panel addSubview:panelBackground];
  [self.panel bringSubviewToFront:panelBackground];
  
  [UIView beginAnimations:nil context:nil];
  [UIView setAnimationDuration:0.5f];
  [self.panel setFrame:CGRectMake(0.0f, self.view.frame.size.height - panelHeight, self.panel.frame.size.width, panelHeight )];
  [panelBackground setAlpha:0.7f];
  [UIView commitAnimations];
  
  //---SAVE BUTTON---
  [self.save removeFromSuperview];
  
  CGRect saveButtonFrame = (CGRect){kSocialButtonPaddingLeft,
    kSocialButtonOriginY - kSaveButtonBorderWidth,
    kSocialButtonWidth + 2 * kSaveButtonBorderWidth,
    kSocialButtonHeight + 2 * kSaveButtonBorderWidth};
  
  self.save = [self createSocialButtonWithFrame:saveButtonFrame
                                backgroundColor:kSaveButtonBackgroundColor
                                    borderColor:kSaveButtonBorderColor
                                    borderWidth:kSaveButtonBorderWidth
                                    socialImage:[UIImage imageNamed:@"save_icon"]
                                     selfAction:@selector(_save)];
  
  //some adjustments
  self.save.clipsToBounds = YES;
  UIEdgeInsets imageEdgeInsets = self.save.imageEdgeInsets;
  imageEdgeInsets.top -= 2 * kSaveButtonBorderWidth;
  self.save.imageEdgeInsets = imageEdgeInsets;
  
  [self.panel addSubview:self.save];
  
  
  //Other buttons, Right to Left
  //---EMAIL BUTTON---
  [self.shareEmailButton removeFromSuperview];
  
  CGFloat emailButtonOriginX = self.panel.frame.size.width - kSocialButtonPaddingRight - kSocialButtonWidth;
  self.shareEmailButton = [self createSocialButtonWithFrame:(CGRect){emailButtonOriginX, kSocialButtonOriginY, kSocialButtonWidth, kSocialButtonHeight}
                                            backgroundColor:kEmailButtonBackgroundColor
                                                borderColor:nil
                                                borderWidth:0.0f
                                                socialImage:[UIImage imageNamed:@"email_icon"]
                                                 selfAction:@selector(shareEmail)];
  [self.panel addSubview:self.shareEmailButton];
  
  
  //---TWITTER BUTTON---
  [self.shareTwitterButton removeFromSuperview];
  
  CGFloat twitterButtonOriginX = emailButtonOriginX - kSpaceBetweenSocialButtons - kSocialButtonWidth;
  self.shareTwitterButton = [self createSocialButtonWithFrame:(CGRect){twitterButtonOriginX, kSocialButtonOriginY, kSocialButtonWidth, kSocialButtonHeight}
                                              backgroundColor:kTwitterButtonBackgroundColor
                                                  borderColor:nil
                                                  borderWidth:0.0f
                                                  socialImage:[UIImage imageNamed:@"twitter_logo"]
                                                   selfAction:@selector(shareTwitter)];
  [self.panel addSubview:self.shareTwitterButton];
  
  
  //---FB BUTTON---
  [self.shareFacebookButton removeFromSuperview];
  
  CGFloat facebookButtonOriginX = twitterButtonOriginX - kSpaceBetweenSocialButtons - kSocialButtonWidth;
  self.shareFacebookButton = [self createSocialButtonWithFrame:(CGRect){facebookButtonOriginX, kSocialButtonOriginY, kSocialButtonWidth, kSocialButtonHeight}
                                               backgroundColor:kFacebookButtonBackgroundColor
                                                   borderColor:nil
                                                   borderWidth:0.0f
                                                   socialImage:[UIImage imageNamed:@"fb_logo"]
                                                    selfAction:@selector(shareFacebook)];
  
  [self.panel addSubview:self.shareFacebookButton];
}

-(UIButton *)createSocialButtonWithFrame:(CGRect)frame
                         backgroundColor:(UIColor *)backgroundColor
                             borderColor:(UIColor *)borderColor
                             borderWidth:(CGFloat)borderWidth
                             socialImage:(UIImage *)socialImage
                              selfAction:(SEL)action

{
  UIButton *socialButton = [UIButton buttonWithType:UIButtonTypeCustom];
  
  socialButton.frame = frame;//CGRectMake(originX, kSocialButtonOriginY, size.width, size.height);
  socialButton.layer.cornerRadius = kSocialButtonCornerRadius;
  socialButton.layer.masksToBounds = YES;
  socialButton.layer.backgroundColor = backgroundColor.CGColor;
  
  if(borderWidth){
    socialButton.layer.borderWidth = borderWidth;
    socialButton.layer.borderColor = borderColor.CGColor;
  }
  
  [socialButton addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
  
  [socialButton setImage:socialImage forState:UIControlStateNormal];
  //socialButton.adjustsImageWhenHighlighted = NO;
  
  socialButton.enabled = self.bInet;
  
  return socialButton;
}

-(UIImage *)prepareUploadableImageWithImage:(UIImage *)image
{
  UIImage *resultImage = image;
  UIImage *tImage = resultImage;
  
  if (resultImage.imageOrientation == UIImageOrientationRight)
    tImage = [UIImage imageWithCGImage:[self CGImageRotatedByAngle:resultImage.CGImage angle:-90.0f]];
  else if (resultImage.imageOrientation == UIImageOrientationDown)
    tImage = [UIImage imageWithCGImage:[self CGImageRotatedByAngle:resultImage.CGImage angle:180.0f]];
  else if (resultImage.imageOrientation == UIImageOrientationLeft)
    tImage = [UIImage imageWithCGImage:[self CGImageRotatedByAngle:resultImage.CGImage angle: 90.0f]];
  
  return resultImage;
}

- (CGImageRef)CGImageRotatedByAngle:(CGImageRef)imgRef angle:(CGFloat)angle {
  CGFloat angleInRadians = angle * (M_PI / 180);
  CGFloat width = CGImageGetWidth(imgRef);
  CGFloat height = CGImageGetHeight(imgRef);
  
  CGRect imgRect = CGRectMake(0, 0, width, height);
  CGAffineTransform transform = CGAffineTransformMakeRotation(angleInRadians);
  CGRect rotatedRect = CGRectApplyAffineTransform(imgRect, transform);
  
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef bmContext = CGBitmapContextCreate(NULL, rotatedRect.size.width, rotatedRect.size.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedFirst);
  CGContextSetAllowsAntialiasing(bmContext, YES);
  CGContextSetInterpolationQuality(bmContext, kCGInterpolationHigh);
  CGColorSpaceRelease(colorSpace);
  CGContextTranslateCTM(bmContext, + (rotatedRect.size.width / 2), + (rotatedRect.size.height / 2));
  CGContextRotateCTM(bmContext, angleInRadians);
  CGContextDrawImage(bmContext, CGRectMake(-width / 2, -height / 2, width, height), imgRef);
  
  CGImageRef rotatedImage = CGBitmapContextCreateImage(bmContext);
  CFRelease(bmContext);
  
  return rotatedImage;
}

#pragma mark - Other

- (void) checkNetworkStatus:(NSNotification *)notice
{
  NetworkStatus internetStatus = [self.internetReachable currentReachabilityStatus];
  NetworkStatus hostStatus     = [self.hostReachable currentReachabilityStatus];
  
  self.bInet = !( internetStatus == NotReachable ||
                 hostStatus     == NotReachable );
  
  // disable sharing buttons if internet connection is absent
  self.shareEmailButton.enabled    = self.bInet;
  self.shareTwitterButton.enabled  = self.bInet;
  self.shareFacebookButton.enabled = self.bInet;
}

- (void)errorMsg:(NSString*)errString
{
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSBundleLocalizedString(@"mTP_sendingEmailErrorTitle", @"Error!")
                                                  message:errString
                                                 delegate:nil
                                        cancelButtonTitle:NSBundleLocalizedString(@"mTP_sendingEmailErrorAlertOkButtonTitle", @"OK")
                                        otherButtonTitles:nil];
  [alert show];
}


#pragma mark - Autorotate Handlers
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
  return toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotate
{
  return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
  return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
  return UIInterfaceOrientationPortrait;
}

@end
