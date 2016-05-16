//
//  ViewController.m
//  nRF UART
//
//  Created by Ole Morten on 1/11/13.
//  Copyright (c) 2013 Nordic Semiconductor. All rights reserved.
//

#import "ViewController.h"

typedef enum
{
    IDLE = 0,
    SCANNING,
    CONNECTED,
} ConnectionState;

typedef enum
{
    LOGGING,
    RX,
    TX,
} ConsoleDataType;

@interface ViewController ()
@property CBCentralManager *cm;
@property ConnectionState state;
@property UARTPeripheral *currentPeripheral;
@end

@implementation ViewController
@synthesize cm = _cm;
@synthesize currentPeripheral = _currentPeripheral;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.cm = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    [self addTextToConsole:@"Did start application" dataType:LOGGING];
    
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    [self.tableView setSeparatorColor:[UIColor clearColor]];
    
    [self.sendTextField setDelegate:self];
}

// Auto UART connect
- (void)viewDidAppear:(BOOL)animated
{

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)connectButtonPressed:(id)sender
{
    [self.sendTextField resignFirstResponder];
    
    switch (self.state) {
        case IDLE:
            self.state = SCANNING;
            
            NSLog(@"Started scan ...");
            [self.connectButton setTitle:@"Scanning ..." forState:UIControlStateNormal];
            
            [self.cm scanForPeripheralsWithServices:@[UARTPeripheral.uartServiceUUID] options:@{CBCentralManagerScanOptionAllowDuplicatesKey: [NSNumber numberWithBool:NO]}];
            break;
            
        case SCANNING:
            self.state = IDLE;

            NSLog(@"Stopped scan");
            [self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];

            [self.cm stopScan];
            break;
            
        case CONNECTED:
            NSLog(@"Disconnect peripheral %@", self.currentPeripheral.peripheral.name);
            [self.cm cancelPeripheralConnection:self.currentPeripheral.peripheral];
            break;
    }
}

- (IBAction)sendTextFieldEditingDidBegin:(id)sender {
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:2] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
//    [self.tableView setContentOffset:CGPointMake(0, 220) animated:YES];
}

- (IBAction)sendTextFieldEditingChanged:(id)sender {
    if (self.sendTextField.text.length > 20)
    {
        [self.sendTextField setBackgroundColor:[UIColor redColor]];
    }
    else
    {
        [self.sendTextField setBackgroundColor:[UIColor whiteColor]];
    }
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField
{
    [self sendButtonPressed:textField];
    return YES;
}

- (IBAction)sendButtonPressed:(id)sender {
    [self.sendTextField resignFirstResponder];
    
    if (self.sendTextField.text.length == 0)
    {
        return;
    }
    
    [self addTextToConsole:self.sendTextField.text dataType:TX];
    
    [self.currentPeripheral writeString:self.sendTextField.text];
}
- (void) didReadHardwareRevisionString:(NSString *)string
{
    [self addTextToConsole:[NSString stringWithFormat:@"Hardware revision: %@", string] dataType:LOGGING];
}

- (void) didReceiveData:(NSString *)string
{
    [self addTextToConsole:string dataType:RX];
}

- (void) addTextToConsole:(NSString *) string dataType:(ConsoleDataType) dataType
{
    NSString *direction;
    switch (dataType)
    {
        case RX:
            direction = @"RX";
            break;
            
        case TX:
            direction = @"TX";
            break;
            
        case LOGGING:
            direction = @"Log";
    }
    
    NSDateFormatter *formatter;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss.SSS"];
    
    self.consoleTextView.text = [self.consoleTextView.text stringByAppendingFormat:@"[%@] %@: %@\n",[formatter stringFromDate:[NSDate date]], direction, string];
    
    [self.consoleTextView setScrollEnabled:NO];
    NSRange bottom = NSMakeRange(self.consoleTextView.text.length-1, self.consoleTextView.text.length);
    [self.consoleTextView scrollRangeToVisible:bottom];
    [self.consoleTextView setScrollEnabled:YES];
}

- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        [self.connectButton setEnabled:YES];
        switch (self.state) {
            case IDLE:
                self.state = SCANNING;
                
                NSLog(@"Started scan ...");
                [self.connectButton setTitle:@"Scanning ..." forState:UIControlStateNormal];
                
                [self.cm scanForPeripheralsWithServices:@[UARTPeripheral.uartServiceUUID] options:@{CBCentralManagerScanOptionAllowDuplicatesKey: [NSNumber numberWithBool:NO]}];
                break;
                
            case SCANNING:
                self.state = IDLE;
                NSLog(@"Stopped scan");
                [self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];
                
                [self.cm stopScan];
                
                break;
                
            case CONNECTED:
                NSLog(@"Disconnect peripheral %@", self.currentPeripheral.peripheral.name);
                [self.cm cancelPeripheralConnection:self.currentPeripheral.peripheral];
                break;
        }
    }
}

- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"Did discover peripheral %@", peripheral.name);
    [self.cm stopScan];
    
    self.currentPeripheral = [[UARTPeripheral alloc] initWithPeripheral:peripheral delegate:self];
    
    [self.cm connectPeripheral:peripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey: [NSNumber numberWithBool:YES]}];
}

- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Did connect peripheral %@", peripheral.name);

    [self addTextToConsole:[NSString stringWithFormat:@"Did connect to %@", peripheral.name] dataType:LOGGING];
    
    self.state = CONNECTED;
    [self.connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
    [self.sendButton setUserInteractionEnabled:YES];
    [self.sendTextField setUserInteractionEnabled:YES];
    
    if ([self.currentPeripheral.peripheral isEqual:peripheral])
    {
        [self.currentPeripheral didConnect];
    }
    [self addTextToConsole:@"1" dataType:TX];
    [self.currentPeripheral writeString:@"1"];
}

- (void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Did disconnect peripheral %@", peripheral.name);
    
    [self addTextToConsole:[NSString stringWithFormat:@"Did disconnect from %@, error code %d", peripheral.name, error.code] dataType:LOGGING];
    
    self.state = IDLE;
    [self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];
    [self.sendButton setUserInteractionEnabled:NO];
    [self.sendTextField setUserInteractionEnabled:NO];
    
    if ([self.currentPeripheral.peripheral isEqual:peripheral])
    {
        [self.currentPeripheral didDisconnect];
    }
}
@end
