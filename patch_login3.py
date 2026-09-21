import os

filepath = r'lib/features/auth/login_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove Sinhala instruction text
text_search = '''                const SizedBox(height: 16),
                const Text(
                  'Smart Entry',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '??????? ??????? ?????? ?????? ?????',
                  style: TextStyle(fontSize: 14, color: Colors.blueGrey),
                ),
                const SizedBox(height: 48),'''

text_replace = '''                const SizedBox(height: 16),
                const Text(
                  'Smart Entry',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),'''

content = content.replace(text_search, text_replace)

# 2. Change Button Text
btn_search = '''                    child: const Text(
                      '????? ????',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),'''

btn_replace = '''                    child: const Text(
                      'LOGIN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),'''

content = content.replace(btn_search, btn_replace)

# 3. Change Mobile Layout (remove scroll)
layout_search = '''            // Mobile layout
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 48.0, left: 32.0, right: 32.0, bottom: 32.0),
                            child: _buildBrandingPanel(context),
                          ),
                        ),
                      ),
                      _buildLoginForm(context, isMobile: true),
                    ],
                  ),
                ),
              ),
            );'''

layout_replace = '''            // Mobile layout
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 48.0, left: 32.0, right: 32.0, bottom: 32.0),
                        child: _buildBrandingPanel(context),
                      ),
                    ),
                  ),
                ),
                _buildLoginForm(context, isMobile: true),
              ],
            );'''

content = content.replace(layout_search, layout_replace)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('Patched successfully')
