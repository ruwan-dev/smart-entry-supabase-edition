import 'app_language.dart';

/// Centralized localization strings for Smart Entry application.
/// Provides pure English strings when English is active,
/// and pure Sinhala strings when Sinhala is active.
class AppStrings {
  static AppLanguage get _lang => AppLanguageService.currentLanguage.value;
  static bool get isSinhala => _lang == AppLanguage.sinhala;
  static bool get isEnglish => _lang == AppLanguage.english;

  // ---------------------------------------------------------------------------
  // General / Common
  // ---------------------------------------------------------------------------
  static String get appName => 'Smart Entry';
  static String get search => isSinhala ? 'සොයන්න...' : 'Search...';
  static String get searchEllipsis => isSinhala ? 'සොයන්න...' : 'Search...';
  static String get save => isSinhala ? 'සුරකින්න' : 'Save';
  static String get update => isSinhala ? 'යාවත්කාලීන කරන්න' : 'Update';
  static String get delete => isSinhala ? 'ඉවත් කරන්න' : 'Delete';
  static String get edit => isSinhala ? 'සංස්කරණය' : 'Edit';
  static String get cancel => isSinhala ? 'අවලංගු කරන්න' : 'Cancel';
  static String get close => isSinhala ? 'වසන්න' : 'Close';
  static String get back => isSinhala ? 'ආපසු' : 'Back';
  static String get yes => isSinhala ? 'ඔව්' : 'Yes';
  static String get no => isSinhala ? 'නැත' : 'No';
  static String get confirm => isSinhala ? 'තහවුරු කරන්න' : 'Confirm';
  static String get yesDelete => isSinhala ? 'ඔව්, ඉවත් කරන්න' : 'Yes, Delete';
  static String get actions => isSinhala ? 'ක්‍රියා' : 'Actions';
  static String get status => isSinhala ? 'තත්ත්වය' : 'Status';
  static String get active => isSinhala ? 'ක්‍රියාකාරී' : 'Active';
  static String get inactive => isSinhala ? 'අක්‍රිය' : 'Inactive';
  static String get loading => isSinhala ? 'පූරණය වෙමින් පවතී...' : 'Loading...';
  static String get processing => isSinhala ? 'සැකසෙමින් පවතී...' : 'Processing...';
  static String get error => isSinhala ? 'දෝෂයකි' : 'Error';
  static String get errorPrefix => isSinhala ? 'දෝෂයකි: ' : 'Error: ';
  static String get success => isSinhala ? 'සාර්ථකයි' : 'Success';
  static String get requiredField => isSinhala ? 'අවශ්‍ය වේ' : 'Required';
  static String get page => isSinhala ? 'පිටුව' : 'Page';
  static String get select => isSinhala ? 'තෝරන්න' : 'Select';
  static String get all => isSinhala ? 'සියල්ල' : 'All';
  static String get date => isSinhala ? 'දිනය' : 'Date';
  static String get year => isSinhala ? 'වර්ෂය' : 'Year';
  static String get month => isSinhala ? 'මාසය' : 'Month';
  static String get total => isSinhala ? 'එකතුව' : 'Total';
  static String get grandTotal => isSinhala ? 'මුළු එකතුව' : 'Grand Total';
  static String get amount => isSinhala ? 'මුදල' : 'Amount';
  static String get quantity => isSinhala ? 'ප්‍රමාණය' : 'Quantity';
  static String get price => isSinhala ? 'මිල' : 'Price';
  static String get rate => isSinhala ? 'ගාස්තුව' : 'Rate';
  static String get description => isSinhala ? 'විස්තරය' : 'Description';
  static String get notes => isSinhala ? 'සටහන්' : 'Notes';
  static String get print => isSinhala ? 'මුද්‍රණය' : 'Print';
  static String get download => isSinhala ? 'බාගත කරන්න' : 'Download';
  static String get online => 'Online';
  static String get offline => 'Offline';
  static String get welcome => isSinhala ? 'ආයුබෝවන්' : 'Welcome';

  // ---------------------------------------------------------------------------
  // Auth / Login
  // ---------------------------------------------------------------------------
  static String get loginTitle => isSinhala ? 'පිවිසෙන්න' : 'Sign In';
  static String get loginSubtitle => isSinhala
      ? 'ඔබගේ ගිණුමට ඇතුළු වීමට විස්තර සපයන්න'
      : 'Enter your credentials to access your account';
  static String get username => isSinhala ? 'පරිශීලක නාමය' : 'Username';
  static String get password => isSinhala ? 'මුරපදය' : 'Password';
  static String get rememberMe => isSinhala ? 'මතක තබා ගන්න' : 'Remember me';
  static String get loginButton => isSinhala ? 'ඇතුල් වන්න' : 'Log In';
  static String get logout => isSinhala ? 'පද්ධතියෙන් ඉවත් වන්න' : 'Logout';
  static String get logoutTitle => isSinhala ? 'පද්ධතියෙන් ඉවත් වීම' : 'Logout';
  static String get logoutConfirm => isSinhala
      ? 'ඔබට පද්ධතියෙන් ඉවත් වීමට අවශ්‍ය බව තහවුරු කරන්නද?'
      : 'Are you sure you want to log out of the system?';

  // ---------------------------------------------------------------------------
  // Customer Management
  // ---------------------------------------------------------------------------
  static String get customers => isSinhala ? 'පාරිභෝගිකයින්' : 'Customers';
  static String get addCustomer => isSinhala ? 'නව පාරිභෝගිකයෙක්' : 'Add Customer';
  static String get editCustomer => isSinhala ? 'පාරිභෝගික තොරතුරු සංස්කරණය' : 'Edit Customer';
  static String get searchCustomer => isSinhala ? 'පාරිභෝගිකයෙකු සොයන්න...' : 'Search customer...';
  static String get refNumber => isSinhala ? 'යොමු අංකය' : 'Reference No';
  static String get refPrefix => isSinhala ? 'යොමුව: ' : 'Ref: ';
  static String get customerName => isSinhala ? 'පාරිභෝගිකයාගේ නම' : 'Customer Name';
  static String get name => isSinhala ? 'නම' : 'Name';
  static String get phone => isSinhala ? 'දුරකථන අංකය' : 'Phone Number';
  static String get address => isSinhala ? 'ලිපිනය' : 'Address';
  static String get pin => isSinhala ? 'රහස්‍ය අංකය (PIN)' : 'PIN Code';
  static String get pinCode => isSinhala ? 'PIN අංකය' : 'PIN';
  static String get enterPin => isSinhala ? 'PIN අංකය ඇතුලත් කරන්න' : 'Enter PIN';
  static String get customerSaved => isSinhala
      ? 'පාරිභෝගිකයා සාර්ථකව සුරකින ලදී'
      : 'Customer saved successfully';
  static String get customerUpdated => isSinhala
      ? 'පාරිභෝගික තොරතුරු යාවත්කාලීන කරන ලදී'
      : 'Customer updated successfully';
  static String get customerDeleted => isSinhala
      ? 'පාරිභෝගිකයා සහ අදාළ සියලුම සටහන් සාර්ථකව ඉවත් කරන ලදී'
      : 'Customer and related records deleted successfully';
  static String get refNumberExists => isSinhala
      ? 'මෙම යොමු අංකය දැනටමත් භාවිතයේ පවතී'
      : 'This reference number is already in use';
  static String get deleteCustomerConfirm => isSinhala ? 'පාරිභෝගිකයා ඉවත් කරන්නද?' : 'Delete Customer?';
  static String deleteCustomerPrompt(String name) => isSinhala
      ? 'ඔබ ස්ථිරවම $name පද්ධතියෙන් ඉවත් කිරීමට අවශ්‍යද?\n(මෙහිදී මොහුගේ සියලුම දෛනික සටහන් මැකී යනු ඇත)'
      : 'Are you sure you want to remove $name permanently?\n(All daily entries for this customer will also be deleted)';
  static String get noCustomersFound => isSinhala
      ? 'පාරිභෝගිකයින් කිසිවෙකු හමුවුණේ නැත.'
      : 'No customers found.';
  static String get highVolumeCustomer => isSinhala ? 'ඉහළ සැපයුම්කරු' : 'High Volume';
  static String get regularCustomer => isSinhala ? 'සාමාන්‍ය' : 'Regular';
  static String get riskCustomer => isSinhala ? 'අවදානම්' : 'Risk';
  static String get monthlyBill => isSinhala ? 'මාසික බිල්පත' : 'Monthly Bill';

  // ---------------------------------------------------------------------------
  // Daily Entries
  // ---------------------------------------------------------------------------
  static String get dailyEntries => isSinhala ? 'දෛනික සටහන්' : 'Daily Entries';
  static String get addDailyEntry => isSinhala ? 'නව දෛනික සටහනක්' : 'New Daily Entry';
  static String get editDailyEntry => isSinhala ? 'දෛනික සටහන සංස්කරණය' : 'Edit Daily Entry';
  static String get grossWeight => isSinhala ? 'දළ බර' : 'Gross Weight';
  static String get waterDeduction => isSinhala ? 'ජල අඩු කිරීම' : 'Water Deduction';
  static String get bagDeduction => isSinhala ? 'උර අඩු කිරීම' : 'Bag Deduction';
  static String get netWeight => isSinhala ? 'නෙට් බර' : 'Net Weight';
  static String get advance => isSinhala ? 'අත්තිකාරම්' : 'Advance';
  static String get fertilizer => isSinhala ? 'පොහොර' : 'Fertilizer';
  static String get teaPackets => isSinhala ? 'තේ කොළ' : 'Tea Packets';
  static String get deductions => isSinhala ? 'අඩු කිරීම්' : 'Deductions';
  static String get totalDeductions => isSinhala ? 'මුළු අඩු කිරීම්' : 'Total Deductions';
  static String get printBill => isSinhala ? 'බිල්පත මුද්‍රණය' : 'Print Receipt';
  static String get saveAndPrint => isSinhala ? 'සුරැකීම සහ මුද්‍රණය' : 'Save & Print';
  static String get saveOnly => isSinhala ? 'සුරකින්න පමණි' : 'Save Only';
  static String get entrySaved => isSinhala ? 'සටහන සාර්ථකව සුරකින ලදී' : 'Entry saved successfully';
  static String get entryUpdated => isSinhala ? 'සටහන සාර්ථකව යාවත්කාලීන කරන ලදී' : 'Entry updated successfully';
  static String get entryDeleted => isSinhala ? 'සටහන සාර්ථකව ඉවත් කරන ලදී' : 'Entry deleted successfully';
  static String get deleteEntryConfirm => isSinhala ? 'මෙම සටහන ඉවත් කරන්නද?' : 'Delete this entry?';
  static String get noEntriesFound => isSinhala ? 'සටහන් කිසිවක් හමුවුණේ නැත.' : 'No entries found.';
  static String get totalNetWeight => isSinhala ? 'මුළු නෙට් බර' : 'Total Net Weight';
  static String get totalAdvance => isSinhala ? 'මුළු අත්තිකාරම්' : 'Total Advance';

  // ---------------------------------------------------------------------------
  // Factory Management
  // ---------------------------------------------------------------------------
  static String get factories => isSinhala ? 'කර්මාන්තශාලා' : 'Factories';
  static String get addFactory => isSinhala ? 'නව කර්මාන්තශාලාවක්' : 'Add Factory';
  static String get editFactory => isSinhala ? 'කර්මාන්තශාලාව සංස්කරණය' : 'Edit Factory';
  static String get factoryName => isSinhala ? 'කර්මාන්තශාලාවේ නම' : 'Factory Name';
  static String get factoryCode => isSinhala ? 'කර්මාන්තශාලා කේතය' : 'Factory Code';
  static String get factoryLedger => isSinhala ? 'කර්මාන්තශාලා ලෙජරය' : 'Factory Ledger';
  static String get factoryReport => isSinhala ? 'කර්මාන්තශාලා වාර්තාව' : 'Factory Report';
  static String get allFactoriesSummary => isSinhala ? 'සියලුම කර්මාන්තශාලා සාරාංශය' : 'All Factories Summary';
  static String get deleteFactoryConfirm => isSinhala ? 'කර්මාන්තශාලාව ඉවත් කරන්නද?' : 'Delete Factory?';
  static String deleteFactoryPrompt(String name) => isSinhala
      ? 'ඔබ ස්ථිරවම $name පද්ධතියෙන් ඉවත් කිරීමට අවශ්‍යද?'
      : 'Are you sure you want to remove $name from the system?';
  static String get factorySaved => isSinhala ? 'කර්මාන්තශාලාව සාර්ථකව සුරකින ලදී' : 'Factory saved successfully';
  static String get factoryUpdated => isSinhala ? 'කර්මාන්තශාලාව යාවත්කාලීන කරන ලදී' : 'Factory updated successfully';
  static String get factoryDeleted => isSinhala ? 'කර්මාන්තශාලාව ඉවත් කරන ලදී' : 'Factory deleted successfully';
  static String get noFactoriesFound => isSinhala ? 'කර්මාන්තශාලා කිසිවක් හමුවුණේ නැත.' : 'No factories found.';
  static String get factoryItems => isSinhala ? 'භාණ්ඩ සහ මිල ගණන්' : 'Items & Prices';

  // ---------------------------------------------------------------------------
  // Reports & Billing
  // ---------------------------------------------------------------------------
  static String get reports => isSinhala ? 'වාර්තා' : 'Reports';
  static String get monthlyReports => isSinhala ? 'මාසික වාර්තා' : 'Monthly Reports';
  static String get monthlyClosing => isSinhala ? 'මාසය අවසන් කිරීම' : 'Monthly Closing';
  static String get generateBills => isSinhala ? 'බිල්පත් සකස් කරන්න' : 'Generate Bills';
  static String get finalizedBills => isSinhala ? 'අවසන් කළ බිල්පත්' : 'Finalized Bills';
  static String get printAll => isSinhala ? 'සියල්ල මුද්‍රණය' : 'Print All';
  static String get sendWhatsApp => isSinhala ? 'WhatsApp මඟින් යවන්න' : 'Send via WhatsApp';
  static String get netPayable => isSinhala ? 'ගෙවිය යුතු ශුද්ධ මුදල' : 'Net Payable';
  static String get totalIncome => isSinhala ? 'මුළු ආදායම' : 'Total Income';
  static String get grossPayable => isSinhala ? 'දළු සඳහා ගෙවීම්' : 'Gross Leaf Payment';
  static String get transportDeduction => isSinhala ? 'ප්‍රවාහන අඩු කිරීම්' : 'Transport Deduction';
  static String get advanceDeduction => isSinhala ? 'අත්තිකාරම් අඩු කිරීම්' : 'Advance Deduction';
  static String get balanceBroughtForward => isSinhala ? 'පසුගිය ශේෂය' : 'Brought Forward';

  // ---------------------------------------------------------------------------
  // Settings Screen
  // ---------------------------------------------------------------------------
  static String get settings => isSinhala ? 'සැකසුම්' : 'Settings';
  static String get itemsTab => isSinhala ? 'අමතර භාණ්ඩ' : 'Items';
  static String get monthlyRatesTab => isSinhala ? 'මාසික ගාස්තු' : 'Monthly Rates';
  static String get ratesListTab => isSinhala ? 'ගාස්තු ලැයිස්තුව' : 'Rates History';
  static String get ratingsTab => isSinhala ? 'ශ්‍රේණිගත කිරීම්' : 'Tier Ratings';
  static String get securityTab => isSinhala ? 'ආරක්ෂිත/දත්ත' : 'Security & Data';
  static String get organizationTab => isSinhala ? 'ආයතනික තොරතුරු' : 'Organization';
  static String get aboutTab => 'About';
  static String get updatesTab => isSinhala ? 'යෙදුම් යාවත්කාලීන' : 'Updates';

  // Language Setting Card
  static String get languageSettings => isSinhala ? 'භාෂාව තේරීම' : 'Language Settings';
  static String get selectLanguage => isSinhala
      ? 'යෙදුමේ භාවිත වන භාෂාව තෝරන්න'
      : 'Select the primary language for the application';
  static String get sinhalaOption => 'සිංහල';
  static String get englishOption => 'English';

  // Settings: Items
  static String get fertilizerAndTeaPrices => isSinhala
      ? 'පොහොර සහ තේ කොළ පැකට් මිල'
      : 'Fertilizer & Tea Packet Prices';
  static String get fertilizer1 => isSinhala ? 'පොහොර 1' : 'Fertilizer 1';
  static String get fertilizer2 => isSinhala ? 'පොහොර 2' : 'Fertilizer 2';
  static String get teaPacket1 => isSinhala ? 'තේ කොළ පැකට් 1' : 'Tea Packet 1';
  static String get teaPacket2 => isSinhala ? 'තේ කොළ පැකට් 2' : 'Tea Packet 2';
  static String get savePrices => isSinhala ? 'මිල සුරකින්න' : 'Save Prices';
  static String get pricesSavedSuccess => isSinhala
      ? 'මිල ගණන් සාර්ථකව සුරකින ලදී!'
      : 'Prices saved successfully!';
  static String get itemsManagementTitle => isSinhala ? 'අමතර භාණ්ඩ කළමනාකරණය' : 'Items Management';
  static String get addItem => isSinhala ? 'නව භාණ්ඩයක් එක් කරන්න' : 'Add New Item';
  static String get editItem => isSinhala ? 'භාණ්ඩය සංස්කරණය' : 'Edit Item';
  static String get itemName => isSinhala ? 'භාණ්ඩයේ නම' : 'Item Name';
  static String get itemCode => isSinhala ? 'කෙටි කේතය (Code)' : 'Short Code';
  static String get unitPrice => isSinhala ? 'ඒකක මිල (Rs)' : 'Unit Price (Rs)';
  static String get maxItemsReached => isSinhala
      ? 'ආයතනයකට එක් කළ හැක්කේ උපරිම භාණ්ඩ 8ක් පමණි.'
      : 'Maximum 8 items limit reached.';
  static String get itemSaved => isSinhala
      ? 'භාණ්ඩ තොරතුරු සාර්ථකව සුරකින ලදී!'
      : 'Item saved successfully!';
  static String get itemDeleted => isSinhala
      ? 'භාණ්ඩය සාර්ථකව ඉවත් කරන ලදී'
      : 'Item deleted successfully';
  static String get deleteItemConfirm => isSinhala
      ? 'මෙම භාණ්ඩය ඉවත් කිරීමට අවශ්‍ය බව තහවුරු කරන්නද?'
      : 'Are you sure you want to delete this item?';

  // Settings: Monthly Rates
  static String get monthlyTeaAndTransportRates => isSinhala
      ? 'මාසික තේ මිල සහ ප්‍රවාහන ගාස්තු'
      : 'Monthly Tea & Transport Rates';
  static String get normalTeaRate => isSinhala
      ? 'සාමාන්‍ය තේ දළු මිල (1kg)'
      : 'Normal Leaf Rate (1kg)';
  static String get superTeaRate => isSinhala
      ? 'සුපිරි තේ දළු මිල (1kg)'
      : 'Super Leaf Rate (1kg)';
  static String get transportRate => isSinhala
      ? 'ප්‍රවාහන ගාස්තුව (1kg)'
      : 'Transport Rate (1kg)';
  static String get saveRates => isSinhala ? 'ගාස්තු සුරකින්න' : 'Save Rates';
  static String get ratesSavedSuccess => isSinhala
      ? 'ගාස්තු සාර්ථකව සුරකින ලදී!'
      : 'Rates saved successfully!';

  // Settings: Ratings
  static String get supplierClassification => isSinhala
      ? 'තේ සැපයුම්කරුවන් වර්ගීකරණය'
      : 'Supplier Tier Classification';
  static String get monthlyMinimumTarget => isSinhala
      ? 'මාසික අවම සැපයුම් ප්‍රමාණය'
      : 'Monthly Minimum Target (kg)';
  static String get saveConfig => isSinhala ? 'සැකසුම් සුරකින්න' : 'Save Configuration';

  // Settings: Security & System
  static String get companyNameTitle => isSinhala ? 'ආයතනයේ නම සැකසීම' : 'Company Name';
  static String get companyNameSubtitle => isSinhala
      ? 'බිල්පත් සහ WhatsApp පණිවිඩ සඳහා භාවිතා කරන ආයතනයේ නම.'
      : 'Company name used for receipts and WhatsApp messages.';
  static String get orgNameField => isSinhala ? 'ආයතනයේ නම' : 'Organization Name';
  static String get addressLine1 => isSinhala ? 'ලිපිනය - පේළිය 1' : 'Address - Line 1';
  static String get addressLine2 => isSinhala ? 'ලිපිනය - පේළිය 2 (විකල්ප)' : 'Address - Line 2 (Optional)';
  static String get addressLine3 => isSinhala ? 'ලිපිනය - පේළිය 3 (විකල්ප)' : 'Address - Line 3 (Optional)';
  static String get addressLine4 => isSinhala ? 'ලිපිනය - පේළිය 4 (විකල්ප)' : 'Address - Line 4 (Optional)';
  static String get companyLine1 => addressLine1;
  static String get companyLine2 => addressLine2;
  static String get companyLine3 => addressLine3;
  static String get companyLine4 => addressLine4;
  static String get contactNumbersField => isSinhala ? 'දුරකථන අංක' : 'Contact Numbers';
  static String get billPageSizeTitle => isSinhala ? 'බිල්පත් පිටු ප්‍රමාණය සැකසීම' : 'Bill Page Dimensions';
  static String get billPageSizeSubtitle => isSinhala
      ? 'මුද්‍රණ යන්ත්‍රය සඳහා පිටුවේ දිග සහ උස (සෙ.මී.) සකසන්න'
      : 'Configure page width and height (cm) for bill printing';
  static String get billPageSizeField => isSinhala ? 'බිල්පත් පිටු ප්‍රමාණය (සෙ.මී.)' : 'Bill Page Size (cm)';
  static String get pageLengthWidth => isSinhala ? 'දිග / පළල (Length - cm)' : 'Length / Width (cm)';
  static String get pageHeight => isSinhala ? 'උස (Height - cm)' : 'Height (cm)';
  static String get companyNameMaxChar => isSinhala
      ? 'ආයතනයේ නම උපරිම අකුරු 25ක් විය යුතුය'
      : 'Company name must not exceed 25 characters';
  static String get saveName => isSinhala ? 'නම සුරකින්න' : 'Save Name';
  static String get companyNameUpdated => isSinhala
      ? 'ආයතනයේ නම සාර්ථකව යාවත්කාලීන කරන ලදී!'
      : 'Company name updated successfully!';

  static String get changePasswordTitle => isSinhala ? 'මුරපදය වෙනස් කිරීම' : 'Change Password';
  static String get changePasswordSubtitle => isSinhala
      ? 'පද්ධතියට ඇතුල්වීමේදී භාවිතා කරන මුරපදය මෙතැනින් වෙනස් කළ හැක.'
      : 'Change the password used to log in to the system here.';
  static String get currentPassword => isSinhala ? 'වත්මන් මුරපදය' : 'Current Password';
  static String get enterCurrentPassword => isSinhala ? 'වත්මන් මුරපදය ඇතුළත් කරන්න' : 'Enter current password';
  static String get newPassword => isSinhala ? 'නව මුරපදය' : 'New Password';
  static String get enterNewPassword => isSinhala ? 'නව මුරපදය ඇතුළත් කරන්න' : 'Enter new password';
  static String get confirmNewPassword => isSinhala ? 'නව මුරපදය තහවුරු කරන්න' : 'Confirm New Password';
  static String get updatePassword => isSinhala ? 'මුරපදය යාවත්කාලීන කරන්න' : 'Update Password';
  static String get passwordUpdatedSuccess => isSinhala
      ? 'මුරපදය සාර්ථකව වෙනස් කරන ලදී!'
      : 'Password changed successfully!';
  static String get passwordsDoNotMatch => isSinhala
      ? 'නව මුරපද නොගැලපේ'
      : 'New passwords do not match';

  static String get databaseBackupTitle => isSinhala ? 'දත්ත සංරක්ෂණය' : 'Database Backup';
  static String get databaseBackupSubtitle => isSinhala
      ? 'ඔබගේ සියලුම දත්ත (.json) ගොනුවක් ලෙස ඔබගේ උපාංගයට සෘජුවම Download කරගන්න.'
      : 'Download all your organization data directly as a .json file.';
  static String get downloadBackup => isSinhala ? 'Backup එක Download කරන්න' : 'Download Backup';
  static String get backupPreparing => isSinhala ? 'Backup සැකසෙමින් පවතී...' : 'Preparing backup...';

  // ---------------------------------------------------------------------------
  // Dashboard / Overview
  // ---------------------------------------------------------------------------
  static String get overview => isSinhala ? 'දළ විශ්ලේෂණය' : 'Overview';
  static String get totalSuppliers => isSinhala ? 'මුළු සැපයුම්කරුවන්' : 'Total Suppliers';
  static String get activeSuppliersToday => isSinhala ? 'අද දින සක්‍රීය සැපයුම්කරුවන්' : 'Active Suppliers Today';
  static String get totalWeightToday => isSinhala ? 'අද දින මුළු බර' : 'Total Weight Today';
  static String get totalWeightMonth => isSinhala ? 'මෙම මස මුළු බර' : 'This Month Total Weight';
  static String get todayEntries => isSinhala ? 'අද දින සටහන්' : "Today's Entries";
  static String get recentTransactions => isSinhala ? 'මෑත ගනුදෙනු' : 'Recent Transactions';

  // ---------------------------------------------------------------------------
  // Additional General & Navigation
  // ---------------------------------------------------------------------------
  static String get searchByNameOrNumber => isSinhala ? 'නම හෝ අංකය මගින් සොයන්න' : 'Search by name or number';
  static String get noDataFound => isSinhala ? 'දත්ත කිසිවක් නොමැත' : 'No data available';
  static String get noHistoryFound => isSinhala ? 'කිසිදු ඉතිහාසයක් නොමැත.' : 'No history found.';
  static String get previous => isSinhala ? 'පෙර' : 'Previous';
  static String get next => isSinhala ? 'ඊළඟ' : 'Next';
  static String get retry => isSinhala ? 'නැවත උත්සාහ කරන්න' : 'Retry';
  static String get refresh => isSinhala ? 'යාවත්කාලීන කරන්න' : 'Refresh';
  static String get attention => isSinhala ? 'අවධානයට!' : 'Attention!';
  static String get view => isSinhala ? 'බලන්න' : 'View';
  static String get viewAll => isSinhala ? 'සියල්ල බලන්න' : 'View All';
  static String get summary => isSinhala ? 'සාරාංශය' : 'Summary';
  static String get activities => isSinhala ? 'ක්‍රියාකාරකම්' : 'Activities';
  static String get noActivitiesFound => isSinhala ? 'ක්‍රියාකාරකම් කිසිවක් නැත' : 'No activities found';
  static String get correctValueRequired => isSinhala ? 'නිවැරදි අගයක් ඇතුළත් කරන්න' : 'Please enter a valid value';
  static String get updateConfirm => isSinhala ? 'තහවුරු කිරීම' : 'Confirmation';
  static String get updateConfirmPrompt => isSinhala ? 'ඔබට මෙම දත්ත යාවත්කාලීන කිරීමට අවශ්‍යද?' : 'Do you want to update this data?';
  static String get savedSuccess => isSinhala ? 'සාර්ථකව සුරැකිණි!' : 'Saved successfully!';
  static String get updatedSuccess => isSinhala ? 'සාර්ථකව යාවත්කාලීන කරන ලදී!' : 'Updated successfully!';
  static String get selectMonth => isSinhala ? 'මාසයක් තෝරන්න' : 'Select Month';
  static String get noMonthSelected => isSinhala ? 'මාසයක් තෝරා නොමැත' : 'No month selected';
  static String get rateNotSet => isSinhala ? 'මිල ඇතුලත් කර නැත' : 'Rate Not Set';
  static String get enterRates => isSinhala ? 'මිල ඇතුලත් කරන්න' : 'Enter Rates';
  static String get ratesNotSetPrompt => isSinhala ? 'මෙම මාසය සඳහා දලු මිල ඇතුලත් කර නොමැත.' : 'Leaf rates not entered for this month.';
  static String get calculated => isSinhala ? 'ගණනය වෙමින් පවතී' : 'Calculating';
  static String get finalized => isSinhala ? 'අවසන් කර ඇත' : 'Finalized';
  static String get finalize => isSinhala ? 'අවසන් කරන්න' : 'Finalize';
  static String get saveAndFinalize => isSinhala ? 'සුරකින්න සහ අවසන් කරන්න' : 'Save & Finalize';
  static String get finalizedSuccess => isSinhala ? 'බිල්පත සාර්ථකව අවසන් කරන ලදී!' : 'Bill finalized successfully!';
  static String get enterReceivedAmount => isSinhala ? 'කර්මාන්තශාලාවෙන් ලැබුණු මුදල ඇතුලත් කරන්න:' : 'Enter amount received from factory:';
  static String get previousArrears => isSinhala ? 'පෙර මාසයේ හිඟ මුදල' : 'Previous Arrears';
  static String get netReceivable => isSinhala ? 'ලැබිය යුතු ශුද්ධ මුදල' : 'Net Receivable';
  static String get grossIncome => isSinhala ? 'දළ ආදායම' : 'Gross Income';
  static String get otherDeductions => isSinhala ? 'වෙනත් අඩු කිරීම්' : 'Other Deductions';
  static String get days => isSinhala ? 'දින' : 'Days';
  static String get startDay => isSinhala ? 'මුල දින' : 'Start Date';
  static String get endDay => isSinhala ? 'අවසාන දින' : 'End Date';
  static String get dateRange => isSinhala ? 'දින පරාසය' : 'Date Range';
  static String get reportType => isSinhala ? 'වාර්තා වර්ගය' : 'Report Type';
  static String get selectCustomer => isSinhala ? 'පාරිභෝගිකයා තෝරන්න' : 'Select Customer';
  static String get pleaseSelectCustomer => isSinhala ? 'කරුණාකර පාරිභෝගිකයෙකු තෝරන්න' : 'Please select a customer';
  static String get analysisResults => isSinhala ? 'විශ්ලේෂණ ප්‍රතිඵල' : 'Analysis Results';
  static String get change => isSinhala ? 'වෙනස් කරන්න' : 'Change';
  static String get from => isSinhala ? 'සිට' : 'from';
  static String get to => isSinhala ? 'දක්වා' : 'to';
  static String get networkError => isSinhala
      ? 'කරුණාකර ඔබගේ අන්තර්ජාල සම්බන්ධතාවය පරීක්ෂා කරන්න. යෙදුම භාවිතයට Internet පහසුකම අත්‍යවශ්‍ය වේ.'
      : 'Please check your internet connection. Internet access is required to use the app.';
  static String get logInWithAnotherAccount => isSinhala ? 'වෙනත් ගිණුමකින් ඇතුල් වන්න' : 'Log in with another account';

  // ---------------------------------------------------------------------------
  // Factory Module Additions
  // ---------------------------------------------------------------------------
  static String get factoryManagement => isSinhala ? 'කර්මාන්තශාලා කළමනාකරණය' : 'Factory Management';
  static String get factoryDirectory => isSinhala ? 'කර්මාන්තශාලා ලැයිස්තුව' : 'Factory Directory';
  static String get combinedSummary => isSinhala ? 'ඒකාබද්ධ සාරාංශය' : 'Combined Summary';
  static String get registerNewFactory => isSinhala ? 'අලුත් කර්මාන්තශාලාවක් ලියාපදිංචි කිරීම' : 'Register New Factory';
  static String get saveFactory => isSinhala ? 'කර්මාන්තශාලාව සුරකින්න' : 'Save Factory';
  static String get leafDetails => isSinhala ? 'තේ දළු විස්තර' : 'Tea Leaf Details';
  static String get normalLeafWeight => isSinhala ? 'සාමාන්‍ය දළු ප්‍රමාණය' : 'Normal Leaf Weight';
  static String get superLeafWeight => isSinhala ? 'සුපිරි දළු ප්‍රමාණය' : 'Super Leaf Weight';
  static String get additionalNotesAndDeductions => isSinhala ? 'අමතර සටහන් සහ අඩු කිරීම්' : 'Additional Notes & Deductions';
  static String get advanceAmount => isSinhala ? 'අත්තිකාරම් මුදල' : 'Advance Amount';
  static String get extraItems => isSinhala ? 'අමතර භාණ්ඩ' : 'Extra Items';
  static String get newRates => isSinhala ? 'නව ගාස්තු' : 'New Rates';
  static String get savedRates => isSinhala ? 'සුරැකි ගාස්තු' : 'Saved Rates';
  static String get factoryFixedSettings => isSinhala ? 'කර්මාන්තශාලා ස්ථාවර සැකසුම් (මාසිකව වෙනස් නොවේ)' : 'Factory Fixed Settings';
  static String get printSummaryReport => isSinhala ? 'සාරාංශ වාර්තාව මුද්‍රණය' : 'Print Summary Report';
  static String get detailedFactorySummary => isSinhala ? 'කර්මාන්තශාලා අනුව විස්තරාත්මක සාරාංශය' : 'Detailed Summary by Factory';
  static String activeFactoriesCount(int count) => isSinhala ? 'සක්‍රීය කර්මාන්තශාලා: $count' : 'Active Factories: $count';
  static String get applicableYear => isSinhala ? 'අදාළ වර්ෂය:' : 'Applicable Year:';
  static String get totalLeafSupply => isSinhala ? 'මුළු දළු සැපයුම' : 'Total Leaf Supply';
  static String get factoryLeafValue => isSinhala ? 'කර්මාන්තශාලා දළු වටිනාකම' : 'Factory Leaf Value';
  static String get fertilizerAndMaterials => isSinhala ? 'පොහොර සහ ද්‍රව්‍ය' : 'Fertilizer & Materials';
  static String get factoryDeductions => isSinhala ? 'කර්මාන්තශාලා අඩුකිරීම්' : 'Factory Deductions';
  static String get totalAdvanceTaken => isSinhala ? 'ලබාගත් මුදල් අත්තිකාරම්' : 'Advances Taken';
  static String get accountBalance => isSinhala ? 'ගිණුම් ශේෂය' : 'Account Balance';
  static String get viewSingleReport => isSinhala ? 'තනි වාර්තාව බලන්න' : 'View Individual Report';
  static String get noFactoryDataForMonth => isSinhala ? 'මෙම මාසය සඳහා කිසිදු කර්මාන්තශාලා දත්තයක් ඇතුළත් කර නොමැත.' : 'No factory data for this month.';
  static String get noMaterialsTaken => isSinhala ? 'පොහොර හෝ ද්‍රව්‍ය ලබාගෙන නොමැත.' : 'No fertilizer or materials taken.';
  static String get totalFertilizer => isSinhala ? 'මුළු පොහොර එකතුව:' : 'Total Fertilizer:';
  static String get leafSupplyDetails => isSinhala ? 'දළු සැපයුම් විස්තරය' : 'Leaf Supply Details';
  static String get report => isSinhala ? 'වාර්තාව' : 'Report';
  static String get pleaseEnterNormalLeafRate => isSinhala ? 'කරුණාකර සාමාන්‍ය දලු මිල ඇතුලත් කරන්න' : 'Please enter normal leaf rate';
  static String get itemsSavedSuccess => isSinhala ? 'භාණ්ඩ සාර්ථකව සුරකින ලදි!' : 'Items saved successfully!';

  // ---------------------------------------------------------------------------
  // Reports Module Additions
  // ---------------------------------------------------------------------------
  static String get accountClosing => isSinhala ? 'ගිණුම් පියවීම' : 'Closing';
  static String get dataAnalysis => isSinhala ? 'දත්ත විශ්ලේෂණය' : 'Analysis';
  static String get whatsapp => 'WhatsApp';
  static String get monthlyClosingTitle => isSinhala ? 'මාසික ගිණුම් අවසන් කිරීම' : 'Monthly Account Closing';
  static String get monthlyClosingSubtitle => isSinhala
      ? 'මෙහිදී අදාළ මාසයේ සියලුම දත්ත පරීක්ෂා කර ස්ථිර කිරීම සිදු කෙරේ.'
      : 'Review and finalize all data for the relevant month here.';
  static String get dataAnalysisSubtitle => isSinhala
      ? 'ඔබට අවශ්‍ය දින පරාසය සහ වර්ගය තෝරා දත්ත තිරය මත විශ්ලේෂණය කරන්න.'
      : 'Select the required date range and category to analyze data on screen.';
  static String get monthlyBusinessSummary => isSinhala ? 'මාසික ව්‍යාපාරික සාරාංශය' : 'Monthly Business Summary';
  static String get receivablePlus => isSinhala ? 'ගෙවීමට ඇති (+) ' : 'Payable (+) ';
  static String get payableMinus => isSinhala ? 'අයවීමට ඇති (-) ' : 'Receivable (-) ';
  static String get netProfitLoss => isSinhala ? 'ශුද්ධ ලාභ/අලාභය' : 'Net Profit/Loss';
  static String get accountsClosedReady => isSinhala
      ? 'මෙම මාසයේ ගිණුම් පියවා අවසන් කර ඇත. වාර්තා නැවත නැරඹිය හැක.'
      : 'Accounts for this month have been closed. Reports can be viewed.';
  static String get ratesNeededPrompt => isSinhala
      ? 'කරුණාකර මෙම මාසය සඳහා අදාළ Rates ඇතුළත් කරන්න.'
      : 'Please enter the applicable rates for this month.';
  static String get readyToClosePrompt => isSinhala
      ? 'දත්ත සූදානම්. මාසික ගිණුම් පියවා වාර්තා සකසන්න.'
      : 'Data ready. Close monthly accounts and generate reports.';
  static String get sendToUnsentOnly => isSinhala ? 'යැවීමට ඉතිරි අයට පමණක් යවන්න' : 'Send to Unsent Only';
  static String get resendToAll => isSinhala ? 'සියල්ලන්ටම නැවත යවන්න' : 'Resend to All';
  static String get individualBills => isSinhala ? 'තනි බිල්පත්' : 'Individual Bills';
  static String get noPhoneNumber => isSinhala ? 'දුරකථන අංකයක් නොමැත' : 'No phone number';
  static String get noBillsOrPhonesToSend => isSinhala
      ? 'යැවීමට අලුත් බිල්පත් හෝ දුරකථන අංක නොමැත!'
      : 'No matching bills or phone numbers to send!';
  static String get monthNotClosedYet => isSinhala
      ? 'මෙම මාසයේ ගිණුම් පියවීම අවසන් කර නැත.'
      : 'Accounts for this month have not been closed yet.';
  static String get monthlyBillReport => isSinhala ? 'මාසික බිල්පත් වාර්තාව' : 'Monthly Bill Report';
  static String get recalculateBill => isSinhala ? 'නැවත සකසන්න' : 'Recalculate Bill';
  static String get revisedBill => isSinhala ? 'සංශෝධිත බිල්පත' : 'Revised Bill';
  static String get thankYou => 'Thank you!';
  static String get poweredByOrbitView => 'Thank You! | Powered by OrbitView Innovations';
  static String get metric => isSinhala ? 'මිණුම' : 'Metric';
  static String get current => isSinhala ? 'වත්මන්' : 'Current';
  static String get recalculated => isSinhala ? 'නැවත සැකසූ' : 'Recalculated';
  static String get difference => isSinhala ? 'වෙනස' : 'Difference';
  static String get monthLockedWarning => isSinhala ? 'මෙම මාසයේ බිල්පත් අවසන් කර ඇති බැවින් දත්ත වෙනස් කළ නොහැක (කියවීම පමණි).' : 'Billing for this month has been closed and locked. Entries cannot be edited (Read Only).';
  static String get lockedMonthBanner => isSinhala ? '🔒 අගුළු දැමූ මාසයකි (කියවීම පමණි)' : '🔒 Locked Month (Read Only)';
  static String get maxNumberExceeded => isSinhala ? 'උපරිම සීමාව 9,999,999,999,999.99 ඉක්මවිය නොහැක' : 'Amount cannot exceed 9,999,999,999,999.99';
  static String get onlyLatestBillCanBeRecalculated => isSinhala
      ? 'නැවත සකස් කළ හැක්කේ අවසන් මාසයේ බිල්පත පමණි.'
      : 'Only the latest finalized monthly bill can be recalculated.';
  static String recalculateBillTitle(String month) => isSinhala
      ? 'බිල්පත නැවත සකසන්න - $month'
      : 'Recalculate Bill - $month';
  static String get reviewRecalculationChanges => isSinhala
      ? 'වත්මන් බිල්පත සහ නැවත සැකසූ බිල්පත අතර වෙනස්කම් සමාලෝචනය කරන්න:'
      : 'Review the changes between the current bill and the recalculated bill:';
  static String subsequentMonthAlertTitle(String month, int year) => isSinhala
      ? 'පසු මාසය පිළිබඳ අවධානයට ($month $year)'
      : 'Subsequent Month Alert ($month $year)';
  static String subsequentMonthAlertBody({
    required String nextMonth,
    required int nextYear,
    required String oldNextArrears,
    required String currentMonth,
    required String newNextArrears,
    required String delta,
  }) => isSinhala
      ? '$nextMonth $nextYear දැනටමත් අවසන් කර ඇත. එහි දැනට පවතින පෙර හිඟ මුදල රු. $oldNextArrears කි.\nමෙම නැවත සැකසීමත් සමඟ, $currentMonth හිඟ මුදල රු. $newNextArrears බවට පත්වේ (වෙනස: $delta).'
      : '$nextMonth $nextYear is already finalized. It currently has previous arrears of Rs. $oldNextArrears.\nWith this recalculation, $currentMonth arrears becomes Rs. $newNextArrears (Difference: $delta).';
  static String autoUpdateSubsequentMonth(String nextMonth, int nextYear) => isSinhala
      ? '$nextMonth $nextYear පෙර හිඟ මුදල සහ ගෙවිය යුතු ශුද්ධ මුදල ස්වයංක්‍රීයව යාවත්කාලීන කරන්න'
      : 'Automatically update $nextMonth $nextYear previous arrears & net payable';
  static String get updatedByLabel => isSinhala
      ? 'යාවත්කාලීන කරන පුද්ගලයාගේ නම (අනිවාර්යයි):'
      : 'Updated By / Your Name (Required):';
  static String get updatedByHint => isSinhala
      ? 'ඔබගේ නම ඇතුළත් කරන්න'
      : 'Enter your name';
  static String get updatedByNameRequired => isSinhala
      ? 'කරුණාකර ඔබගේ නම ඇතුළත් කරන්න.'
      : 'Please enter your name.';
  static String get updatedBy => isSinhala ? 'යාවත්කාලීන කළේ' : 'Updated by';
  static String get note => isSinhala ? 'සටහන' : 'Note';
  static String get reason => isSinhala ? 'හේතුව' : 'Reason';
  static String get archivedOn => isSinhala ? 'සුරැකි දිනය' : 'Archived on';
  static String get latestUpdate => isSinhala ? 'අවසන් යාවත්කාලීන කිරීම' : 'Latest Update';
  static String get youHaveBillChanges => isSinhala
      ? 'බිල්පතෙහි නව වෙනස්කම් ඇත!'
      : 'You have bill changes!';
  static String get billChangesPrompt => isSinhala
      ? 'දෛනික සටහන් හෝ ගාස්තු වල අලුත් වෙනස්කම් හමු විය. කරුණාකර බිල්පත නැවත සකසන්න.'
      : 'Daily entries or rates for this month have been updated. Please recalculate this bill.';
  static String get noBillChangesDetected => isSinhala
      ? 'වෙනස්කම් කිසිවක් හමු නොවීය. මෙම බිල්පත දැනටමත් දෛනික සටහන් සමඟ සම්පූර්ණයෙන්ම යාවත්කාලීනයි.'
      : 'No changes detected. This bill is already fully up to date with daily entries.';
  static String get billUpToDate => isSinhala
      ? 'බිල්පත යාවත්කාලීනයි'
      : 'Bill is up to date';
  static String get billChangesDetected => isSinhala
      ? 'නව වෙනස්කම් ඇත'
      : 'Changes Detected';
  static String get recalculationReasonLabel => isSinhala
      ? 'නැවත සැකසීමට හේතුව (විකල්ප සටහනක්):'
      : 'Reason for recalculation (optional note):';
  static String get recalculationReasonHint => isSinhala
      ? 'උදා: දෛනික සටහන් වල 2 වන දින දළු බර නිවැරදි කිරීම'
      : 'e.g. Corrected day 2 leaf weight in daily entries';
  static String get confirmAndUpdateBill => isSinhala
      ? 'තහවුරු කර බිල්පත යාවත්කාලීන කරන්න'
      : 'Confirm & Update Bill';
  static String get recalculatingBillProgress => isSinhala
      ? 'දෛනික සටහන් වලින් බිල්පත නැවත සකසමින් පවතී...'
      : 'Recalculating bill from daily entries...';
  static String get savingUpdatedBillProgress => isSinhala
      ? 'යාවත්කාලීන කළ බිල්පත දත්ත ගබඩාවේ සුරකිමින් පවතී...'
      : 'Saving updated bill to database...';
  static String get billRecalculatedSuccess => isSinhala
      ? 'බිල්පත සාර්ථකව නැවත සකසා යාවත්කාලීන කරන ලදී!'
      : 'Bill successfully recalculated and updated!';
  static String get recalculationErrorPrefix => isSinhala
      ? 'නැවත සැකසීමේ දෝෂයකි: '
      : 'Recalculation error: ';
  static String get compareWithOriginal => isSinhala
      ? 'මුල් පිටපත සමඟ සසඳන්න'
      : 'Compare with Original';
  static String comparisonTitle(int rev, String month) => isSinhala
      ? 'සැසඳීම: මුල් පිටපත (Rev 1) සහ වත්මන් (Rev $rev) - $month'
      : 'Comparison: Original (Rev 1) vs Active (Rev $rev) - $month';
  static String get latestRevisionLabel => isSinhala
      ? 'අවසන් සංශෝධනය: '
      : 'Latest Revision: ';
  static String get viewingPrefix => isSinhala ? 'නරඹන්නේ: ' : 'Viewing: ';
  static String get printSelectedVersion => isSinhala
      ? 'තෝරාගත් පිටපත මුද්‍රණය'
      : 'Print Selected Version';
  static String get printSlip => isSinhala ? 'බිල්පත මුද්‍රණය' : 'Print Slip';
  static String get sendBillWhatsApp => isSinhala
      ? 'WhatsApp මඟින් යවන්න'
      : 'Send Bill (WhatsApp)';

  // ---------------------------------------------------------------------------
  // Auth Module Additions
  // ---------------------------------------------------------------------------
  static String get enterUsernameAndPasswordPrompt => isSinhala
      ? 'කරුණාකර පරිශීලක නාමය සහ මුරපදය ඇතුළත් කරන්න.'
      : 'Please enter username and password.';
  static String get invalidUsername => isSinhala ? 'පරිශීලක නාමය වැරදියි.' : 'Invalid username.';
  static String get invalidPassword => isSinhala
      ? 'මුරපදය වැරදියි! කරුණාකර නැවත උත්සාහ කරන්න.'
      : 'Invalid password! Please try again.';
  static String get verifyingPassword => isSinhala ? 'මුරපදය පරීක්ෂා කරමින්...' : 'Verifying password...';
  static String get loginTagline => isSinhala
      ? '"දෛනික තේ දළු කළමනාකරණය\nවඩාත් පහසුවෙන් සහ නිවැරදිව."'
      : '"Daily tea leaf management\nsimple, fast, and accurate."';

  // ---------------------------------------------------------------------------
  // Dashboard & Analytics Additions
  // ---------------------------------------------------------------------------
  static String get today => isSinhala ? 'අද' : 'Today';
  static String get thisWeek => isSinhala ? 'මෙම සතිය' : 'This Week';
  static String get thisMonth => isSinhala ? 'මෙම මාසය' : 'This Month';
  static String get last6Months => isSinhala ? 'පසුගිය මාස 6' : 'Last 6 Months';
  static String get lastYear => isSinhala ? 'පසුගිය වසර' : 'Last Year';
  static String get daily => isSinhala ? 'දිනපතා' : 'Daily';
  static String get monthly => isSinhala ? 'මාසිකව' : 'Monthly';
  static String get yearly => isSinhala ? 'වාර්ෂිකව' : 'Yearly';
  static String get dailyLeafTotal => isSinhala ? 'දෛනික දළු එකතුව' : 'Daily Leaf Total';
  static String get low => isSinhala ? 'අඩු' : 'Low';
  static String get high => isSinhala ? 'වැඩි' : 'High';
  static String outstandingAlertPrompt(String amount) => isSinhala
      ? 'ව්‍යාපාරයට රු. $amount ක හිඟ මුදලක් අයවීමට ඇත.'
      : 'The business has an outstanding balance of Rs. $amount receivable.';
  static String get incomeAndExpense => isSinhala ? 'ආදායම් සහ වියදම්' : 'Income & Expenses';
  static String get incomeRs => isSinhala ? 'ආදායම (Rs)' : 'Income (Rs)';
  static String get expenseRs => isSinhala ? 'වියදම (Rs)' : 'Expense (Rs)';
  static String get topSuppliers => isSinhala ? 'වැඩිම දළු සැපයුම්කරුවන්' : 'Top Leaf Suppliers';
  static String get allSuppliers => isSinhala ? 'සියලුම සැපයුම්කරුවන්' : 'All Suppliers';
  static String get totalOutstandingAmount => isSinhala ? 'මුළු හිඟ මුදල' : 'Total Outstanding Balance';
  static String monthlySummaryTitle(String month) => isSinhala ? '$month මාසික සාරාංශය' : '$month Monthly Summary';
  static String get leafWeightTotal => isSinhala ? 'මුළු දළු බර' : 'Total Leaf Weight';
  static String get advanceCash => isSinhala ? 'අත්තිකාරම් මුදල්' : 'Advance Cash';
  static String get transportCost => isSinhala ? 'ප්‍රවාහන වියදම' : 'Transport Cost';
  static String get itemCost => isSinhala ? 'භාණ්ඩ වියදම' : 'Item Cost';
  static String get teaPacketCost => isSinhala ? 'තේ පැකට් වියදම' : 'Tea Packet Cost';
  static String get receivableAmount => isSinhala ? 'අයවියයුතු මුදල' : 'Receivable Amount';
  static String get payableAmount => isSinhala ? 'ලබා දිය යුතු මුදල' : 'Payable Amount';
  static String get profitOrLoss => isSinhala ? 'ලාභ/අලාභය' : 'Profit / Loss';
  static String get allCustomersActive => isSinhala ? 'සියලුම පාරිභෝගිකයින් සක්‍රියයි!' : 'All customers are active!';
  static String get noOutstandingBalances => isSinhala ? 'කිසිදු හිඟ මුදලක් නොමැත 🎉' : 'No outstanding balances 🎉';
  static String get lastLeafDate => isSinhala ? 'අවසන් දළු දුන් දිනය' : 'Last Supply Date';
  static String get leafInThatMonth => isSinhala ? 'එම මාසයේ දළු' : 'Leaf in Month';
  static String get debtOutstanding => isSinhala ? 'හිඟ මුදල (ණය)' : 'Outstanding Debt';
  static String get byRating => isSinhala ? 'ශ්‍රේණිගත කිරීම් අනුව' : 'By Rating';
  static String get customerAnalysis => isSinhala ? 'පාරිභෝගික විශ්ලේෂණය' : 'Customer Analysis';
  static String get overallData => isSinhala ? 'සමස්ත දත්ත' : 'Overall Data';
  static String get withDebt => isSinhala ? 'ණය සහිත අය' : 'With Debt';
  static String get inactiveCustomers => isSinhala ? 'අක්‍රිය පාරිභෝගිකයින්' : 'Inactive Customers';
  static String get monthlyDeductionPct => isSinhala ? 'මාසික කපාගැනීමේ %' : 'Monthly Deduction %';
  static String get maxCreditLimit => isSinhala ? 'ලබා දිය හැකි උපරිම ණය මුදල' : 'Maximum Credit Limit';
  static String get basedOn12Months => isSinhala ? '(මාස 12 කින් අයකර ගැනීමේ පදනම මත)' : '(Based on 12-month recovery)';
  static String get cannotRecover => isSinhala ? 'අයකරගත නොහැක' : 'Cannot recover';

  // ---------------------------------------------------------------------------
  // Factory Daily Allocation & Collection Summary
  // ---------------------------------------------------------------------------
  static String get dailyCollectionAndAllocations => isSinhala ? 'දවසේ දළු එකතුව සහ කර්මාන්තශාලා වෙන් කිරීම්' : 'Daily Leaf Collection & Allocations';
  static String get totalCollectedLeafToday => isSinhala ? 'එදින එකතු කළ මුළු දළු' : 'Total Collected Leaf Today';
  static String get allocatedToOtherFactories => isSinhala ? 'වෙනත් කර්මාන්තශාලාවලට වෙන් කළ දළු' : 'Allocated to Other Factories';
  static String get noOtherFactoryAllocations => isSinhala ? 'වෙනත් කර්මාන්තශාලාවලට වෙන් කර නොමැත' : 'No allocations to other factories';
  static String get availableForThisFactory => isSinhala ? 'මෙම කර්මාන්තශාලාවට ඉතිරි දළු' : 'Available for This Factory';
  static String get remainingAfterEntry => isSinhala ? 'ඇතුළත් කිරීමෙන් පසු ඉතිරි' : 'Remaining After Entry';
  static String get overAllocated => isSinhala ? 'එකතුවට වඩා වැඩියි' : 'Over Allocated';
  static String get otherFactoriesBreakdown => isSinhala ? 'වෙනත් කර්මාන්තශාලා විස්තර' : 'Other Factories Breakdown';
  static String get applyAvailable => isSinhala ? 'ඉතිරි ප්‍රමාණය යොදන්න' : 'Apply Available';

  // ---------------------------------------------------------------------------
  // Executive Dashboard & Income Analytics
  // ---------------------------------------------------------------------------
  static String get netDealerIncome => isSinhala ? 'ආයතනික ආදායම' : 'Dealer Income';
  static String get dealerGrossMargin => isSinhala ? 'දළ ලාභය' : 'Gross Margin';
  static String get factoryRevenue => isSinhala ? 'කර්මාන්තශාලා ආදායම' : 'Factory Revenue';
  static String get supplierPayout => isSinhala ? 'සැපයුම්කරුවන්ගේ දළු වියදම' : 'Supplier Leaf Cost';
  static String get marginPerKg => isSinhala ? 'කිලෝවක දළ ලාභය' : 'Margin / Kg';
  static String get superLeafRatio => isSinhala ? 'සුපිරි දළු අනුපාතය' : 'Super Leaf Ratio';
  static String get normalLeaf => isSinhala ? 'සාමාන්‍ය දළු' : 'Normal Leaf';
  static String get superLeaf => isSinhala ? 'සුපිරි දළු' : 'Super Leaf';
  static String get capitalExposure => isSinhala ? 'හිඟ මුදල් / ණය' : 'Capital in Field';
  static String get dailyAverageIntake => isSinhala ? 'දෛනික සාමාන්‍ය දළු' : 'Daily Average Intake';
  static String get activeSuppliers => isSinhala ? 'සක්‍රිය සැපයුම්කරුවන්' : 'Active Suppliers';
  static String get financialOverview => isSinhala ? 'මූල්‍ය හා ආදායම් දළ විශ්ලේෂණය' : 'Financial & Income Overview';
  static String get leafHarvestAnalytics => isSinhala ? 'දළු අස්වනු විශ්ලේෂණය' : 'Leaf Harvest Analytics';
  static String get qualityBreakdown => isSinhala ? 'ගුණාත්මක අනුපාතය' : 'Quality Breakdown';
  static String get factoryRevenueVsCost => isSinhala ? 'කර්මාන්තශාලා ආදායම හා සැපයුම්කරුවන්ගේ වියදම' : 'Factory Inflow vs Supplier Cost';
  static String get deliveredToFactories => isSinhala ? 'කර්මාන්තශාලා සැපයුම' : 'Delivered to Factories';
  static String get totalLeafIntake => isSinhala ? 'දළු එකතුව' : 'Total Intake';
  static List<String> get weekdayShortNames => isSinhala
      ? ['සඳු', 'අඟ', 'බදා', 'බ්‍රහ', 'සිකු', 'සෙන', 'ඉරි']
      : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static String get monthHarvestTotal => isSinhala ? 'මාසික දළු එකතුව' : 'Month Total Leaf';
  static String get peakHarvestDay => isSinhala ? 'වැඩිම අස්වනු දිනය' : 'Peak Harvest Day';
  static String get harvestDays => isSinhala ? 'අස්වනු ලැබූ දින' : 'Harvest Days';
  static String get harvestConsistency => isSinhala ? 'අස්වනු අනුපාතය' : 'Consistency';
  static String get pendingFactoryEntry => isSinhala ? 'කර්මාන්තශාලා සටහන් පොරොත්තුවෙන්' : 'Pending Factory Entry';
  static String get monthlyOverview => isSinhala ? 'මාසික දළ විශ්ලේෂණය' : 'Monthly Overview';
  static String get transitLossOrGain => isSinhala ? 'ප්‍රවාහන බර වෙනස' : 'Transit Weight Variance';
  static String get factoryDeliveredWeight => isSinhala ? 'කර්මාන්තශාලාවට යැවූ බර' : 'Factory Delivered Weight';
  static String get pendingMonthlyRates => isSinhala ? 'මාසික මිල බලාපොරොත්තුවෙන්' : 'Rates Pending';
  static String get itemsIssued => isSinhala ? 'නිකුත් කළ ද්‍රව්‍ය' : 'Items Issued';





  // ---------------------------------------------------------------------------
  // Month Names Helper
  // ---------------------------------------------------------------------------
  static List<String> get monthNames => isSinhala
      ? ['ජනවාරි', 'පෙබරවාරි', 'මාර්තු', 'අප්‍රේල්', 'මැයි', 'ජූනි', 'ජූලි', 'අගෝස්තු', 'සැප්තැම්බර්', 'ඔක්තෝබර්', 'නොවැම්බර්', 'දෙසැම්බර්']
      : ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  static String getMonthName(int month) => monthNames[(month - 1).clamp(0, 11)];

  static List<String> get monthShortNames => isSinhala
      ? ['ජන', 'පෙබ', 'මාර්', 'අප්‍රේ', 'මැයි', 'ජූනි', 'ජූලි', 'අගෝ', 'සැප්', 'ඔක්', 'නොවැ', 'දෙසැ']
      : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String getMonthShortName(int month) => monthShortNames[(month - 1).clamp(0, 11)];

  /// Formats a month string like '2026 September' into the active language (e.g. '2026 සැප්තැම්බර්').
  static String formatDisplayMonth(String? displayMonth) {
    if (displayMonth == null || displayMonth.trim().isEmpty) return '';
    final parts = displayMonth.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return displayMonth;

    final englishMonths = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthIdx = englishMonths.indexWhere(
      (m) => m.toLowerCase() == parts[1].toLowerCase(),
    );
    if (monthIdx != -1) {
      return isSinhala ? '${parts[0]} ${getMonthName(monthIdx + 1)}' : displayMonth;
    }
    return displayMonth;
  }
}
