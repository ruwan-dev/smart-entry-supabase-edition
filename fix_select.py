import os

files = [
    'lib/core/customer/add_customer_screen.dart',
    'lib/core/customer/customer_form_screen.dart'
]

for filepath in files:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # The script mistakenly changed:
    # }).select().eq('organization_id', AppState.currentOrganizationId.value ?? '');
    # back to:
    # }).select();
    
    content = content.replace(
        "}).select().eq('organization_id', AppState.currentOrganizationId.value ?? '');",
        "}).select();"
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"Fixed {filepath}")
