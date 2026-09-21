import os

filepath = r'lib/features/dashboard/customer_analysis_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

search_str = '''                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          '???? ?????????????',
                          '',
                          Icons.people_alt_rounded,
                          primaryAppColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '?? ???? ??',
                          '',
                          Icons.account_balance_wallet_rounded,
                          const Color(0xFFD32F2F),
                        ),
                      ),
                    ],
                  ),'''

replace_str = '''                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 450) {
                        return Column(
                          children: [
                            _buildStatCard(
                              '???? ?????????????',
                              '',
                              Icons.people_alt_rounded,
                              primaryAppColor,
                            ),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              '?? ???? ??',
                              '',
                              Icons.account_balance_wallet_rounded,
                              const Color(0xFFD32F2F),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              '???? ?????????????',
                              '',
                              Icons.people_alt_rounded,
                              primaryAppColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              '?? ???? ??',
                              '',
                              Icons.account_balance_wallet_rounded,
                              const Color(0xFFD32F2F),
                            ),
                          ),
                        ],
                      );
                    },
                  ),'''

content = content.replace(search_str, replace_str)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('Patched customer analysis layout')
