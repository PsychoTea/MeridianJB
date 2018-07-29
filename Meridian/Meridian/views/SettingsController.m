//
//  SettingsController.m
//  Meridian
//
//  Created by Sticktron on 2018-04-03.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#import "SettingsController.h"
#import "Preferences.h"

@interface SettingsController ()
@property (weak, nonatomic) IBOutlet UISwitch *tweaksEnabledSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *startLaunchDaemonsSwitch;
@property (weak, nonatomic) IBOutlet UITextField *bootNonceEntryField;
@property (weak, nonatomic) IBOutlet UISwitch *startDropbearSwitch;
@property (weak, nonatomic) IBOutlet UISegmentedControl *dropbearPortControl;
@property (weak, nonatomic) IBOutlet UITableViewCell *psychoTwitterCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *issueTrackerCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *sourceCodeCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *websiteCell;
@end


@implementation SettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tweaksEnabledSwitch.on = tweaksAreEnabled();
    _startLaunchDaemonsSwitch.on = startLaunchDaemonsIsEnabled();
    _bootNonceEntryField.text = [NSString stringWithFormat:@"0x%llx", getBootNonceValue()];
    _startDropbearSwitch.on = startDropbearIsEnabled();
    _dropbearPortControl.selectedSegmentIndex = listenPort();
    
    _bootNonceEntryField.delegate = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)openLink:(NSString *)url {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url] options:@{} completionHandler:nil];
}

- (IBAction)tweaksEnabledValueChanged:(UISwitch *)sender {
    setTweaksEnabled(sender.isOn);
}

- (IBAction)startLaunchDaemonsValueChanged:(UISwitch *)sender {
    setStartLaunchDaemonsEnabled(sender.isOn);
}

- (IBAction)startDropbearValueChanged:(UISwitch *)sender {
    setStartDropbearEnabled(sender.isOn);
}

- (IBAction)dropbearPortValueChanged:(UISegmentedControl *)sender {
    setListenPort(sender.selectedSegmentIndex);
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (IBAction)bootNonceEditingEnded:(UITextField *)sender {
    const char *generatorInput = [sender.text UTF8String];
    
    if (strcmp(generatorInput, "0x0") == 0) {
        // Reset/disable the generator
        setBootNonceValue(0x0);
        
        // Set it to the Electra nonce
        _bootNonceEntryField.text = [NSString stringWithFormat:@"0x%llx", getBootNonceValue()];
        return;
    }
    
    char compareString[22];
    uint64_t rawGeneratorValue;
    sscanf(generatorInput, "0x%16llx", &rawGeneratorValue);
    sprintf(compareString, "0x%016llx", rawGeneratorValue);
    
    if (strcmp(compareString, generatorInput) != 0) {
        
        NSString *message = [NSString stringWithFormat:@"The generator you provided was invalid. The generator should be in the format '0x1234567890123456'"];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Invalid Generator"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"Close"
                                                              style:UIAlertActionStyleCancel
                                                            handler:nil];
        
        [alert addAction:closeAction];
        [self presentViewController:alert animated:YES completion:nil];
        
        // Reset/disable the generator
        setBootNonceValue(0x0);
        
        // Set it to the Electra nonce
        _bootNonceEntryField.text = [NSString stringWithFormat:@"0x%llx", getBootNonceValue()];
        
        return;
    }
    
    setBootNonceValue(rawGeneratorValue);
}

#pragma mark - Table view
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (cell == self.psychoTwitterCell) {
        [self openLink:@"http://www.twitter.com/iBSparkes"];
    } else if (cell == self.websiteCell) {
        [self openLink:@"https://meridian.sparkes.zone"];
        
    } else if (cell == self.sourceCodeCell) {
        [self openLink:@"https://github.com/PsychoTea/MeridianJB"];
        
    } else if (cell == self.issueTrackerCell) {
        [self openLink:@"https://github.com/PsychoTea/MeridianJB/issues"];
    }
}


#pragma mark - Navigation

@end
