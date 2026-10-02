import 'package:flutter/material.dart';

class TeamSection extends StatelessWidget {
  final List<dynamic> shopResponseTeam;


  const TeamSection({super.key, required this.shopResponseTeam});

  @override
  Widget build(BuildContext context) {
    final List<dynamic> teamList = shopResponseTeam ?? [];

    final visibleTeamMembers = teamList.where((member) => member['memberVisibility'] == true).toList();

    if (visibleTeamMembers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.groups, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text(
                "Meet Our Team",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            "No team members to display at the moment.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.groups, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text(
              "Meet Our Team",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 180, // Adjust height to fit the card content
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: visibleTeamMembers.map((member) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildTeamCard(
                    name: member['name'],
                    role: member['role'],
                    imageUrl: member['imgUrl'],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );

    // return Column(
    //   crossAxisAlignment: CrossAxisAlignment.start,
    //   children: [
    //     const Row(
    //       children: [
    //         Icon(Icons.groups, color: Colors.deepPurple),
    //         SizedBox(width: 8),
    //         Text(
    //           "Meet Our Team",
    //           style: TextStyle(
    //             fontSize: 20,
    //             fontWeight: FontWeight.bold,
    //             color: Colors.black87,
    //           ),
    //         ),
    //       ],
    //     ),
    //     const SizedBox(height: 10),
    //     Wrap(
    //       spacing: 16,
    //       runSpacing: 16,
    //       children: visibleTeamMembers.map((member) {
    //         return _buildTeamCard(
    //           name: member['name'],
    //           role: member['role'],
    //           imageUrl: member['imgUrl'],
    //         );
    //       }).toList(),
    //     ),
    //   ],
    // );
  }

  Widget _buildTeamCard({
    required String name,
    required String role,
    required String imageUrl,
  }) {
    final isValidImage = imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.hasAbsolutePath == true;

    return Card(
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          // boxShadow: const [
          //   BoxShadow(
          //     // color: Colors.black12,
          //     blurRadius: 8,
          //     offset: Offset(0, 3),
          //   ),
          // ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: isValidImage
                  ? Image.network(
                imageUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.deepPurple,
                  child: Icon(Icons.person, color: Colors.white, size: 40),
                ),
              )
                  : const CircleAvatar(
                radius: 35,
                backgroundColor: Colors.deepPurple,
                child: Icon(Icons.person, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name.isNotEmpty ? name : "Unnamed",
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              role.isNotEmpty ? role : "Role Unknown",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
