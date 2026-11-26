/// Shared category catalogue used by Worker skills and Poster gig listings.
/// Keep labels stable: notification matching compares these values exactly.
class HustleLinkCategories {
  HustleLinkCategories._();

  static const List<String> all = [
    'Accounting & Bookkeeping',
    'Admin & Virtual Assistance',
    'Agriculture & Farming',
    'Automotive & Mechanics',
    'Audio & Music',
    'Beauty & Personal Care',
    'Carpentry & Furniture',
    'Cleaning & Laundry',
    'Construction & Masonry',
    'Content Writing & Editing',
    'Cooking & Catering',
    'Customer Service',
    'Data Entry & Analysis',
    'Delivery & Logistics',
    'Design & Graphics',
    'Electrical & Electronics',
    'Event Planning & Management',
    'Fashion & Tailoring',
    'Film & Photography',
    'Gardening & Landscaping',
    'Hair & Makeup',
    'Healthcare & Caregiving',
    'Home & Appliance Repairs',
    'IT & Software Development',
    'Installation & Maintenance',
    'Interior Design',
    'Marketing & Social Media',
    'Moving & Errands',
    'Painting & Decoration',
    'Plumbing',
    'Printing & Signage',
    'Sales & Retail',
    'Security Services',
    'Teaching & Tutoring',
    'Transport & Driving',
    'Welding & Fabrication',
    'Writing & Translation',
    'Other / General',
  ];

  static String canonicalize(String value) {
    final normalized = value.trim().toLowerCase();
    for (final category in all) {
      if (category.toLowerCase() == normalized) return category;
    }
    const aliases = {
      'electrical': 'Electrical & Electronics',
      'carpentry': 'Carpentry & Furniture',
      'event planning': 'Event Planning & Management',
      'interior design': 'Interior Design',
      'driving': 'Transport & Driving',
      'music': 'Audio & Music',
      'electrician': 'Electrical & Electronics',
      'electrical works': 'Electrical & Electronics',
      'electronics': 'Electrical & Electronics',
      'graphic design': 'Design & Graphics',
      'graphics': 'Design & Graphics',
      'design': 'Design & Graphics',
      'software': 'IT & Software Development',
      'coding': 'IT & Software Development',
      'programming': 'IT & Software Development',
      'plumber': 'Plumbing',
      'plumbing works': 'Plumbing',
      'mechanic': 'Automotive & Mechanics',
      'automobile repairs': 'Automotive & Mechanics',
      'hair': 'Hair & Makeup',
      'makeup': 'Hair & Makeup',
      'cleaning': 'Cleaning & Laundry',
      'catering': 'Cooking & Catering',
      'photography': 'Film & Photography',
      'photographer': 'Film & Photography',
      'writing': 'Content Writing & Editing',
      'tutoring': 'Teaching & Tutoring',
      'teaching': 'Teaching & Tutoring',
      'welding': 'Welding & Fabrication',
      'fabrication': 'Welding & Fabrication',
      'repairs': 'Home & Appliance Repairs',
      'maintenance': 'Installation & Maintenance',
      'social media': 'Marketing & Social Media',
      'virtual assistant': 'Admin & Virtual Assistance',
      'data analysis': 'Data Entry & Analysis',
      'fashion': 'Fashion & Tailoring',
      'tailoring': 'Fashion & Tailoring',
    };
    return aliases[normalized] ?? value.trim();
  }

  static List<String> canonicalizeAll(Iterable<String> values) {
    return values
        .map(canonicalize)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}
