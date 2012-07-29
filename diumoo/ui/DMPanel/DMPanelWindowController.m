//
//  DMPannelWindowController.m
//  diumoo
//
//  Created by Shanzi on 12-6-12.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "DMPanelWindowController.h"
#import "DMDoubanAuthHelper.h"
#import "DMPlayRecordHandler.h"
#import "StatusItemView.h"
#import "DMPrefsPanelDataProvider.h"

DMPanelWindowController *sharedWindow;

@interface DMPanelWindowController ()

@end

@implementation DMPanelWindowController
@synthesize view,delegate,openURL,menubarController;

+(DMPanelWindowController*)sharedWindowController
{
    if (sharedWindow == nil) {
        sharedWindow = [[DMPanelWindowController alloc] init];
    }
    return sharedWindow;
}

-(id) init
{
    self = [super initWithWindowNibName:@"DMPanelWindowController"];
    if(self){
        self.menubarController = [[MenubarController alloc] init];
        [menubarController setAction:@selector(togglePanel:) withTarget:self];
    }
    return self;
}

-(void) awakeFromNib
{
    [super awakeFromNib];
    NSWindow* panel = self.window;
    
    [panel setLevel:NSPopUpMenuWindowLevel];
    [panel setBackgroundColor:[NSColor whiteColor]];
    [panel setOpaque:NO];
    [panel setAlphaValue:0.95];

    [loadingIndicator startAnimation:nil];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(accountStateChanged:)
                                                 name:AccountStateChangedNotification
                                               object:nil];
    
}

-(void) accountStateChanged:(NSNotification*)n
{
    DMDoubanAuthHelper* helper = [DMDoubanAuthHelper sharedHelper];
    DMLog(@"%@",helper);
    if (helper.username) {
        [userIconButton setImage:[helper getUserIcon]];
        [usernameTextField setStringValue:helper.username];
        
        NSString* ratedCountString= [NSString stringWithFormat:@"♥ %ld",helper.likedSongsCount];
        [ratedCountTextField setStringValue:ratedCountString];
        
        [ratedCountTextField setHidden:NO];
        [usernameTextField setHidden:NO];
        
        [rateButton setEnabled:YES];
        [banButton setEnabled:[self.delegate canBanSong]];
        
        [popupMenuController setPrivateChannelEnabled:YES];
    }
    else {
        
        [userIconButton setImage:[NSImage imageNamed:NSImageNameUser]];
        [ratedCountTextField setStringValue:@""];
        [usernameTextField setStringValue:@""];
        [ratedCountTextField setHidden:YES];
        [usernameTextField setHidden:YES];
        
        [popupMenuController setPrivateChannelEnabled:NO];
        
        [rateButton setEnabled:NO];
        [banButton setEnabled:NO];
    }
    [popupMenuController updateChannelList];
}


-(void) channelChangeActionWithSender:(id)sender
{
    NSInteger tag = [sender tag];
    NSString* channel = [NSString stringWithFormat:@"%ld",tag];
    if ([self.delegate channelChangedTo:channel]) {
        
        if (tag == 0 || tag == -3) {
            if ([DMDoubanAuthHelper sharedHelper].username) {
                [banButton setEnabled:YES];
            }
        }
        else {
            [banButton setEnabled:NO];
        }
        
        [popupMenuController updateChannelMenuWithSender:sender];
    }
}


-(void) controlAction:(id)sender
{
    NSInteger tag = [sender tag];
    switch (tag) {
        case 0:
            [self.delegate playOrPause];
            break;
        case 1:
            [self.delegate skip];
            break;
        case 2:
            [self.delegate rateOrUnrate];
            break;
        case 3:
            [self.delegate ban];
            break;
        case 4:
            [self.delegate volumeChange:[sender floatValue]];
            break;
        case 5:
            [PLTabPreferenceControl showPrefsAtIndex:ACCOUNT_PANEL_ID];
            break;
        case 6:
            [self togglePanel:nil];
            [[NSApplication sharedApplication] terminate:nil];
        case 7:
            [PLTabPreferenceControl showPrefsAtIndex:0];
            break;
    }
}

-(void) specialAction:(id)sender
{
    NSInteger tag = [sender tag];
    switch (tag) {
        case 0:
            // 退出special
            [self.delegate exitedSpecialMode];
            break;
        case -2:
            // 打开网页
        {
            NSURL* url = [NSURL URLWithString:self.openURL];
            [[NSWorkspace sharedWorkspace] openURL:url];
        }
        break;
    }
}

-(void)shareAction:(id)sender
{
    [self.delegate share:(SNS_CODE)[sender tag]];
}

-(void)unlockUIWithError:(BOOL)has_err
{
    [loadingIndicator stopAnimation:nil];
    [popupMenuController unlockChannelMenuButton];
    
    if(has_err){
        [coverView setHidden:YES];
        [indicateString setStringValue:@"发生网络错误，请尝试重启应用"];
    }
    else{
        [loadingIndicator setHidden:YES];
        [indicateString setHidden:YES];
        
        [coverView setHidden:NO];
    }
}

-(void) setRated:(BOOL)rated
{
    if ([rateButton isEnabled]) {
        if (rated){
            [menubarController setMixed:YES];
            [rateButton setImage:[NSImage imageNamed:@"rate_red.png"]];
        }
        else {
            [menubarController setMixed:NO];
            [rateButton setImage:[NSImage imageNamed:@"rate.png"]];
        }
    }
}

-(void) countRated:(NSInteger)count
{
    DMDoubanAuthHelper* helper = [DMDoubanAuthHelper sharedHelper];
    if(helper.username){
        helper.likedSongsCount += count ;
        NSString* ratedCountString= [NSString stringWithFormat:@"♥ %ld",helper.likedSongsCount];
        [ratedCountTextField setStringValue:ratedCountString];
    }
}

-(void) setPlaying:(BOOL)playing
{
    if (playing) {
        [playPauseButton setImage:[NSImage imageNamed:@"pause.png"]];
    }
    else {
        [playPauseButton setImage:[NSImage imageNamed:@"play.png"]];
    }
}

-(void) setPlayingCapsule:(DMPlayableCapsule *)capsule
{
    if ([coverView isHidden]) {
        [self unlockUIWithError:NO];
    }

    [capsule prepareCoverWithCallbackBlock:^(NSImage *image) {
            [coverView setAlbumImage:image];
    }];

    
    [coverView setPlayingInfo:capsule.title :capsule.artist :capsule.albumtitle];
}

-(void) showAlbumWindow:(id)sender
{
    [NSApp activateIgnoringOtherApps:YES];
    [[DMPlayRecordHandler sharedRecordHandler] open];
}

-(void) playDefaultChannel
{
    if (popupMenuController.publicMenu == nil) {
        [popupMenuController updateChannelList];
    }
    
    NSMenuItem* currentItem=popupMenuController.currentChannelMenuItem;

    
    if ([DMDoubanAuthHelper sharedHelper].username == nil) {
        [popupMenuController setPrivateChannelEnabled:NO];
        [rateButton setEnabled:NO];
        [banButton setEnabled:NO];
        if (currentItem && currentItem.tag <= 0) {
            [self channelChangeActionWithSender:[popupMenuController.publicMenu 
                                                 itemWithTag:1]];
            return;
        }
    }
    
    if(currentItem){
        [self channelChangeActionWithSender:currentItem];
    }
    else {
        [self channelChangeActionWithSender:[popupMenuController.publicMenu 
                                             itemWithTag:1]];
    }
}

-(void) toggleSpecialWithDictionary:(NSDictionary *)info;
{
    
    if (info) {
        DMLog(@"play info : %@",info);
        NSString* title = [info objectForKey:@"title"];
        NSString* artist = [info objectForKey:@"artist"];
        NSString* type = [info objectForKey:@"typestring"];

        self.openURL = [DOUBAN_URL_PRIFIX stringByAppendingFormat:@"subject/%@/",[info objectForKey:@"aid"]];
        
        [popupMenuController enterSpecialPlayingModeWithTitle:title
                                                       artist:artist
                                                andTypeString:type];
    }
    else {
        self.openURL = nil;
        [popupMenuController exitSepecialPlayingMode];
    }
}

// ------------------------------ 弹出窗口 ----------------------------

- (NSRect)statusRectForWindow:(NSWindow *)window
{
    NSRect statusRect = NSZeroRect;
    StatusItemView *statusItemView = nil;

    statusItemView = menubarController.statusItemView;

    statusRect = statusItemView.globalRect;
    statusRect.origin.y = NSMinY(statusRect) - NSHeight(statusRect);

    return statusRect;
}

- (BOOL)hasActivePanel
{
    return _hasActivePanel;
}

- (void)setHasActivePanel:(BOOL)flag
{
    if (_hasActivePanel != flag)
    {
        _hasActivePanel = flag;
        
        if (_hasActivePanel)
        {
            [self openPanel];
        }
        else
        {
            [self closePanel];
        }
    }
}

- (void)windowDidResignKey:(NSNotification *)notification;
{
    if ([[self window] isVisible])
    {
        [self windowWillClose:nil];
    }
}

- (void)windowWillClose:(NSNotification *)notification
{
    self.hasActivePanel = NO;
    self.menubarController.hasActiveIcon = NO;
}

-(void) openPanel
{
    NSWindow *panel = [self window];
    
    NSRect screenRect = [[panel screen] frame];
    NSRect statusRect = [self statusRectForWindow:panel];
    
    NSRect panelRect = [panel frame];
    CGFloat panelWidth = NSWidth(panelRect);
    CGFloat screenWidth = NSWidth(screenRect);
    CGFloat left = NSMinX(statusRect);
    CGFloat leftSafe = screenWidth - panelWidth;
    
    panelRect.origin.x = roundf(left<leftSafe?left:leftSafe);
    panelRect.origin.y = NSMaxY(statusRect) - NSHeight(panelRect);
    
    
    [NSApp activateIgnoringOtherApps:NO];
    [panel setFrame:panelRect display:YES];
    [panel makeKeyAndOrderFront:panel];
}

-(void) closePanel
{
    NSWindow *panel = [self window];
    [panel orderOut:nil];
}

- (IBAction)togglePanel:(id)sender
{
    self.menubarController.hasActiveIcon = !self.menubarController.hasActiveIcon;
    self.hasActivePanel = self.menubarController.hasActiveIcon;
}


@end
