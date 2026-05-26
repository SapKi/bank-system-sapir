// Layout IDs (from Tooling API query)
String customerLayoutId    = '00hC2000001RdRKIA0';
String loanRequestLayoutId = '00hC2000001RdRMIA0';
String auditLogLayoutId    = '00hC2000001RdRJIA0';

// Profile IDs
String adminProfileId    = '00eC2000001LLSHIA4';
String platformProfileId = '00eC2000001LLSQIA4';
String standardProfileId = '00eC2000001LLSqIAO';

List<String> profileIds = new List<String>{ adminProfileId, platformProfileId, standardProfileId };
List<String> layoutIds  = new List<String>{ customerLayoutId, loanRequestLayoutId, auditLogLayoutId };

// Query existing ProfileLayout assignments to avoid duplicates
Set<String> existingKeys = new Set<String>();
for (ProfileLayout pl : [SELECT ProfileId, LayoutId FROM ProfileLayout
                          WHERE ProfileId IN :profileIds AND LayoutId IN :layoutIds]) {
    existingKeys.add(pl.ProfileId + '_' + pl.LayoutId);
}

List<ProfileLayout> toInsert = new List<ProfileLayout>();
for (String profileId : profileIds) {
    for (String layoutId : layoutIds) {
        String key = profileId + '_' + layoutId;
        if (!existingKeys.contains(key)) {
            toInsert.add(new ProfileLayout(ProfileId = profileId, LayoutId = layoutId));
        }
    }
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Inserted ' + toInsert.size() + ' layout assignments.');
} else {
    System.debug('All assignments already exist.');
}
